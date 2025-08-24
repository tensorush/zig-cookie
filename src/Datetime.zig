//! HTTP datetime format.

const std = @import("std");

const Datetime = @This();

date: Date,
time: Time,

const DAYS_PER_ERA = 365 * 400 + 97;

pub const Error = error{
    InvalidFormat,
};

pub const Date = struct {
    pub const Weekday = enum {
        Mon,
        Tue,
        Wed,
        Thu,
        Fri,
        Sat,
        Sun,

        /// Compute weekday from days since UNIX Epoch.
        /// https://howardhinnant.github.io/date_algorithms.html#weekday_from_days
        pub fn fromDays(days: i64) Weekday {
            return @enumFromInt(if (days >= -4) @mod(days + 4, 7) else @mod(days + 5, 7) + 6);
        }
    };

    pub const Month = enum {
        Jan,
        Feb,
        Mar,
        Apr,
        May,
        Jun,
        Jul,
        Aug,
        Sep,
        Oct,
        Nov,
        Dec,
    };

    weekday: Weekday,
    day: u8,
    month: Month,
    year: u16,

    /// Compute civil date from UNIX timestamp.
    /// https://howardhinnant.github.io/date_algorithms.html#civil_from_days
    pub fn fromTimestamp(timestamp: i64) Date {
        const days: u32 = @intCast(@divTrunc(timestamp, std.time.s_per_day));
        const z = days + 719_468;
        const era = if (z >= 0) @divFloor(z, DAYS_PER_ERA) else @divFloor(z - DAYS_PER_ERA - 1, DAYS_PER_ERA);
        const doe = z - era * DAYS_PER_ERA;
        const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36_524) - @divFloor(doe, 146_096), 365);
        const y = yoe + era * 400;
        const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
        const mp = @divFloor(5 * doy + 2, 153);
        const m = if (mp < 10) mp + 3 else mp - 9;
        return .{
            .weekday = .fromDays(days),
            .day = @intCast(doy - @divFloor(153 * mp + 2, 5) + 1),
            .month = @enumFromInt(m),
            .year = @intCast(if (m < 3) y + 1 else y),
        };
    }
};

pub const Time = struct {
    hour: u8,
    minute: u8,
    second: u8,
};

/// Parse datetime from string.
pub fn parse(str: []const u8) Error!Datetime {
    const value = std.mem.trim(u8, str, " ");
    if (value.len != 29) {
        return Error.InvalidFormat;
    }
    return .{
        .date = .{
            .weekday = std.meta.stringToEnum(Date.Weekday, value[0..3]) orelse return Error.InvalidFormat,
            .day = std.fmt.parseInt(u8, value[5..7], 10) catch return Error.InvalidFormat,
            .month = std.meta.stringToEnum(Date.Month, value[8..11]) orelse return Error.InvalidFormat,
            .year = std.fmt.parseInt(u16, value[12..16], 10) catch return Error.InvalidFormat,
        },
        .time = .{
            .hour = std.fmt.parseInt(u8, value[17..19], 10) catch return Error.InvalidFormat,
            .minute = std.fmt.parseInt(u8, value[20..22], 10) catch return Error.InvalidFormat,
            .second = std.fmt.parseInt(u8, value[23..25], 10) catch return Error.InvalidFormat,
        },
    };
}

/// Create datetime from UNIX timestamp.
pub fn fromTimestamp(timestamp: i64) Datetime {
    const date: Date = .fromTimestamp(timestamp);
    var seconds = @mod(timestamp, std.time.s_per_day);
    const hours = @divFloor(seconds, std.time.s_per_hour);
    seconds -= hours * std.time.s_per_hour;
    const minutes = @divFloor(seconds, std.time.s_per_min);
    seconds -= minutes * std.time.s_per_min;
    return .{
        .date = .{
            .weekday = date.weekday,
            .day = date.day,
            .month = date.month,
            .year = date.year,
        },
        .time = .{
            .hour = @intCast(hours),
            .minute = @intCast(minutes),
            .second = @intCast(seconds),
        },
    };
}

/// Print datetime to writer.
pub fn format(self: Datetime, writer: *std.io.Writer) std.io.Writer.Error!void {
    try writer.print("{t}, {d:0>2} {t} {d} {d:0>2}:{d:0>2}:{d:0>2} GMT", .{
        self.date.weekday,
        self.date.day,
        self.date.month,
        self.date.year,
        self.time.hour,
        self.time.minute,
        self.time.second,
    });
}
