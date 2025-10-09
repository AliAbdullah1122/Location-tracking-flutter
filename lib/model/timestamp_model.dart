import 'dart:convert';

Timestamps timestampsFromJson(String str) =>
    Timestamps.fromJson(json.decode(str));

String timestampsToJson(Timestamps data) => json.encode(data.toJson());

class Timestamps {
  Timestamps({
    this.timeIn,
    this.timeOut,
    this.breakStart,
    this.breakEnd,
  });

  String? timeIn;
  String? timeOut;
  String? breakStart;
  String? breakEnd;

  factory Timestamps.fromJson(Map<String, dynamic> json) => Timestamps(
        timeIn: json["time_in"],
        timeOut: json["time_out"],
        breakStart: json["break_start"],
        breakEnd: json["break_end"],
      );

  Map<String, dynamic> toJson() => {
        "time_in": timeIn,
        "time_out": timeOut,
        "break_start": breakStart,
        "break_end": breakEnd,
      };
}
