import 'package:flutter/material.dart';

enum DialogsAction { yes, cancel }

class AlertDialogs {
  static Future<DialogsAction> yesCancelDialog(
    BuildContext context,
    String title,
    String body,
  ) async {
    final action = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          title: Text(title,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: "SofiaPro",
                fontStyle: FontStyle.normal,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              )),
          content: Text(body,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: "SofiaPro",
                fontStyle: FontStyle.normal,
                fontSize: 14,
              )),
          actions: <Widget>[
            // ignore: deprecated_member_use
            FlatButton(
              onPressed: () => Navigator.of(context).pop(DialogsAction.cancel),
              child: const Text(
                'Cancel',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            // ignore: deprecated_member_use
            FlatButton(
              onPressed: () => Navigator.of(context).pop(DialogsAction.yes),
              child: const Text(
                'Confirm',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.w700),
              ),
            )
          ],
        );
      },
    );
    return (action != null) ? action : DialogsAction.cancel;
  }
}
