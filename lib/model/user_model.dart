// ignore_for_file: unnecessary_this

import 'dart:convert';

User userFromJson(String str) => User.fromJson(json.decode(str));
String userToJson(User data) => json.encode(data.toJson());

class User {
  User({
    this.user,
    this.ratio,
    this.fName,
    this.lName,
    this.phone,
    this.image,
  });

  int? user;
  int? ratio;
  String? fName;
  String? lName;
  String? phone;
  String? image;

  factory User.fromJson(Map<String, dynamic> json) => User(
        user: json["user"],
        ratio: json["ratio"],
        fName: json["f_name"],
        lName: json["l_name"],
        phone: json["phone"],
        image: json["image"],
      );

  Map<String, dynamic> toJson() => {
        "user": this.user,
        "ratio": this.ratio,
        "f_name": this.fName,
        "l_name": this.lName,
        "phone": this.phone,
        "image": this.image,
      };

  Map<String, dynamic> toUserJson() => {
        "user": this.user,
        "ratio": this.ratio,
        "f_name": this.fName,
        "l_name": this.lName,
        "phone": this.phone,
        "image": this.image,
      };

  toUserUserJson() => json.encode({
        "user": this.user,
        "ratio": this.ratio,
        "f_name": this.fName,
        "l_name": this.lName,
        "phone": this.phone,
        "image": this.image,
      });
}
