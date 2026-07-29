module Promotable
  module Rules
    # Time-of-day / day-of-week eligibility window.
    #
    # preferences:
    #   days_of_week — array of integers 0..6 (0=Sunday), default all days
    #   start_hour   — integer 0..23, default 0
    #   end_hour     — integer 0..24, default 24 (exclusive; 24 = end of day)
    #   time_zone    — TZ name string (default "UTC"); comparisons use this
    #
    # Example — weekdays 9am-5pm:
    #   { days_of_week: [1,2,3,4,5], start_hour: 9, end_hour: 17, time_zone: "America/New_York" }
    class TimeWindowRule < Base
      store_accessor :preferences, :days_of_week, :start_hour, :end_hour, :time_zone

      def self.preference_fields
        [
          { name: :days_of_week, type: :array,   default: [ 0, 1, 2, 3, 4, 5, 6 ] },
          { name: :start_hour,   type: :integer, default: 0 },
          { name: :end_hour,     type: :integer, default: 24 },
          { name: :time_zone,    type: :string,  default: "UTC" }
        ]
      end

      private

      def evaluate(_promotable, _context = {})
        zone = time_zone.presence || "UTC"
        now  = Time.current.in_time_zone(zone)

        day_ok?(now) && hour_ok?(now)
      end

      def day_ok?(now)
        allowed = Array(days_of_week).map(&:to_i)
        return true if allowed.empty?

        allowed.include?(now.wday)
      end

      def hour_ok?(now)
        first = (start_hour.presence || 0).to_i
        last  = (end_hour.presence   || 24).to_i
        now.hour >= first && now.hour < last
      end
    end
  end
end
