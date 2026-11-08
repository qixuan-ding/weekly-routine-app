import 'package:flutter/material.dart';

import 'data/database.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await PlannerDatabase.open();
    final planner = await database.load();
    runApp(WeeklyRoutineApp(database: database, initial: planner));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              child: SelectableText(
                'Weekly Routine could not open its local data.\n\n$error\n\nYour database has been left intact. Close the app and check disk access before retrying.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
