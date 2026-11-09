import Foundation

/// Turns a drafted trip into one that works: every stop on a day the place is
/// open, at a time you could be there, within the hours it keeps.
///
/// The draft says which places go on which day and roughly when. It comes
/// from a model, so nothing in it is taken on trust: places it invented or
/// repeated are left out, and each day is timed by `DayPlanner` with every
/// place's hours that weekday and the travel between stops. A stop that
/// doesn't work is tried in a different order, then at a different time, then
/// on a different day, and is left out only when none of those opens the door.
/// Whatever changed is reported, so the traveller can see the plan was checked.
///
/// Daylight and rain aren't weighed: most trips are planned further ahead
/// than a forecast reaches. The trip screen flags both once the dates are near.
struct TripBuilder {

    struct DraftStop: Equatable {
        var placeID: String
        /// Minutes past midnight.
        var start: Int
        var reason: String = ""
    }

    struct DraftDay: Equatable {
        var theme: String = ""
        var stops: [DraftStop] = []
    }

    struct Stop: Identifiable, Equatable {
        var id = UUID()
        var place: Place
        var start: Int
        var reason: String
        /// The time it was given before checking, to count what checking moved.
        var drafted: Int

        var itineraryStop: ItineraryStop {
            ItineraryStop(placeID: place.id, startMinute: start, durationMinutes: place.typicalMinutes)
        }
    }

    struct Day: Identifiable, Equatable {
        var date: Date
        var theme: String
        var stops: [Stop]
        var id: Date { date }
    }

    /// What checking changed. Days are indexes into the trip.
    enum Fix: Equatable {
        /// `closedThatDay` when the place is shut all day on the day drafted;
        /// otherwise its hours didn't fit around that day's other stops.
        case moved(Place, from: Int, to: Int, closedThatDay: Bool)
        case reordered(day: Int)
        case dropped(Place, from: Int, closedThatDay: Bool)
    }

    struct Result: Equatable {
        var days: [Day]
        var fixes: [Fix] = []
        /// Stops that kept their day and order but start at least ten
        /// minutes from the time drafted, for travel or an opening time.
        var retimed = 0

        var stopCount: Int { days.reduce(0) { $0 + $1.stops.count } }
    }

    var city: City
    /// One per day of the trip, in order.
    var dates: [Date]
    var gettingAround: GettingAround = .transit
    /// Nothing is planned for a time today that has already passed.
    var now: Date = .now
    var calendar: Calendar = .current

    /// Few enough that `DayPlanner` tries every order.
    static let maxStopsPerDay = 7
    static let earliestStart = 6 * 60
    static let latestStart = 23 * 60 + 55
    /// Slack on every hop, for finding the door and the way out.
    static let buffer = 10
    /// How far making room for a moved stop may push that day's own stops.
    static let longestPush = 30

    // MARK: From a draft

    func build(_ draft: [DraftDay], from places: [Place]) -> Result {
        let byID = Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var used = Set<String>()
        var days = dates.enumerated().map { index, date -> Day in
            let drafted = index < draft.count ? draft[index] : DraftDay()
            let stops = drafted.stops.compactMap { stop -> Stop? in
                guard let place = byID[stop.placeID], place.event == nil, place.typicalMinutes > 0,
                      used.insert(place.id).inserted else { return nil }
                let start = min(max(stop.start, Self.earliestStart), Self.latestStart) / 5 * 5
                return Stop(place: place, start: start, reason: stop.reason, drafted: start)
            }
            return Day(date: date, theme: drafted.theme,
                       stops: Array(stops.sorted(by: Self.inTimeOrder).prefix(Self.maxStopsPerDay)))
        }

        var fixes: [Fix] = []
        var evicted: [(stop: Stop, from: Int, closedThatDay: Bool)] = []
        for index in days.indices {
            let settled = settle(days[index].stops, on: index)
            days[index].stops = settled.stops
            if settled.reordered { fixes.append(.reordered(day: index)) }
            evicted += settled.evicted.map { ($0.stop, index, $0.closedThatDay) }
        }
        for item in evicted {
            if let home = home(for: item.stop, besides: item.from, in: days) {
                days[home.day].stops = home.stops
                fixes.append(.moved(item.stop.place, from: item.from, to: home.day,
                                    closedThatDay: item.closedThatDay))
            } else {
                fixes.append(.dropped(item.stop.place, from: item.from, closedThatDay: item.closedThatDay))
            }
        }
        let retimed = days.flatMap(\.stops).filter { abs($0.start - $0.drafted) >= 10 }.count
        return Result(days: days, fixes: fixes, retimed: retimed)
    }

    // MARK: Without a draft

    /// A trip from the places alone: each day is the first-day planner's pick
    /// of what the days before it left. Used when there's no model to ask.
    func starter(among places: [Place]) -> Result {
        var used = Set<String>()
        let days = dates.map { date -> Day in
            let isToday = calendar.isDate(date, inSameDayAs: now)
            let planner = FirstDayPlanner(city: city, date: date, interests: Set(FirstDayPlanner.interests),
                                          pace: .balanced,
                                          availableFrom: isToday ? max(540, now.minuteOfDay + 15) : 540,
                                          calendar: calendar)
            let picks = planner.propose(among: places.filter { !used.contains($0.id) })
            used.formUnion(picks.map(\.id))
            return Day(date: date, theme: "", stops: picks.map {
                Stop(place: $0.place, start: $0.start, reason: $0.reason, drafted: $0.start)
            })
        }
        return Result(days: days)
    }

    // MARK: One day

    /// Times a day's stops and keeps what works. What doesn't is handed back
    /// for another day.
    private func settle(_ drafted: [Stop], on dayIndex: Int)
        -> (stops: [Stop], reordered: Bool, evicted: [(stop: Stop, closedThatDay: Bool)]) {
        var stops = drafted
        var reordered = false
        var evicted: [(stop: Stop, closedThatDay: Bool)] = []
        var retimed = Set<UUID>()

        while !stops.isEmpty {
            stops.sort(by: Self.inTimeOrder)
            let planner = planner(for: stops, on: dayIndex)
            let plan = planner.current()
            guard let bad = plan.visits.firstIndex(where: { !Self.works($0) }) else {
                for index in stops.indices { stops[index].start = plan.visits[index].start }
                break
            }
            let visit = plan.visits[bad]

            // No order or time opens a place that's shut all day.
            if visit.problem != .closedAllDay {
                let best = planner.best()
                if best.visits.allSatisfy(Self.works) {
                    stops = best.visits.compactMap { visit in
                        guard var stop = stops.first(where: { $0.id == visit.id }) else { return nil }
                        stop.start = visit.start
                        stop.drafted = visit.start
                        return stop
                    }
                    reordered = true
                    break
                }
                if retimed.insert(stops[bad].id).inserted,
                   let start = openStart(for: stops[bad], visit: visit, on: dayIndex) {
                    stops[bad].start = start
                    continue
                }
            }
            evicted.append((stops.remove(at: bad), visit.problem == .closedAllDay))
        }
        return (stops, reordered, evicted)
    }

    /// Another time the same day at which the place is open: when it next
    /// opens, or early enough to be out by closing.
    private func openStart(for stop: Stop, visit: DayPlanner.Visit, on dayIndex: Int) -> Int? {
        guard let hours = stop.place.weeklyHours?.day(weekday(dayIndex)) else { return nil }
        switch visit.problem {
        case .closedOnArrival:
            guard let opening = hours.nextOpening(after: visit.start), opening.start <= Self.latestStart
            else { return nil }
            return opening.start
        case .closesEarly(let minutes):
            let earlier = (visit.start - minutes) / 5 * 5
            return earlier >= Self.earliestStart && hours.span(containing: earlier) != nil ? earlier : nil
        default:
            return nil
        }
    }

    /// A day with room for a stop its own day couldn't keep, emptiest first.
    private func home(for stop: Stop, besides origin: Int, in days: [Day]) -> (day: Int, stops: [Stop])? {
        let emptiestFirst = days.indices.filter { $0 != origin }
            .sorted { (days[$0].stops.count, $0) < (days[$1].stops.count, $1) }
        for index in emptiestFirst where days[index].stops.count < Self.maxStopsPerDay {
            if stop.place.weeklyHours?.day(weekday(index)).isClosedAllDay == true { continue }
            for start in startsWorthTrying(for: stop, among: days[index].stops) {
                var moved = stop
                moved.start = start
                let trial = (days[index].stops + [moved]).sorted(by: Self.inTimeOrder)
                let plan = planner(for: trial, on: index).current()
                guard plan.visits.allSatisfy(Self.works) else { continue }

                let settled = zip(trial, plan.visits).map { before, visit -> Stop in
                    var after = before
                    after.start = visit.start
                    if after.id == stop.id { after.drafted = visit.start }
                    return after
                }
                let pushesTheDay = zip(trial, settled).contains { before, after in
                    before.id != stop.id && after.start - before.start > Self.longestPush
                }
                if !pushesTheDay { return (index, settled) }
            }
        }
        return nil
    }

    /// The time of day the stop was drafted for, then straight after each of
    /// the day's own stops.
    private func startsWorthTrying(for stop: Stop, among stops: [Stop]) -> [Int] {
        let afterEach = stops.map { other -> Int in
            let free = other.start + other.place.typicalMinutes + Self.buffer
                + TravelEstimate.minutes(from: other.place.coordinate, to: stop.place.coordinate, by: gettingAround)
            return (free + 4) / 5 * 5
        }
        return ([stop.drafted] + afterEach).filter { $0 <= Self.latestStart }
    }

    // MARK: Timing

    private func planner(for stops: [Stop], on dayIndex: Int) -> DayPlanner {
        let weekday = weekday(dayIndex)
        let isToday = calendar.isDate(dates[dayIndex], inSameDayAs: now)
        return DayPlanner(
            stops: stops.map { stop in
                DayPlanner.Stop(id: stop.id, duration: stop.place.typicalMinutes,
                                isOutdoors: stop.place.category.isOutdoors,
                                hours: stop.place.weeklyHours?.day(weekday),
                                isMeal: stop.place.category == .food)
            },
            slots: stops.map(\.start),
            travel: stops.map { from in
                stops.map { to in
                    from.id == to.id ? 0 : TravelEstimate.minutes(from: from.place.coordinate,
                                                                 to: to.place.coordinate,
                                                                 by: gettingAround) + Self.buffer
                }
            },
            availableFrom: isToday ? now.minuteOfDay + 15 : nil
        )
    }

    /// Google's weekday for a day of the trip: Sunday is 0.
    private func weekday(_ dayIndex: Int) -> Int {
        calendar.component(.weekday, from: dates[dayIndex]) - 1
    }

    private static func works(_ visit: DayPlanner.Visit) -> Bool {
        visit.problem == nil && visit.start <= latestStart
    }

    private static func inTimeOrder(_ a: Stop, _ b: Stop) -> Bool {
        (a.start, a.place.id) < (b.start, b.place.id)
    }
}
