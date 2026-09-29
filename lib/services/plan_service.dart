import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/question_plan.dart';
import 'callable_errors.dart';

/// Raised when the four questions could not be written.
class PlanFailed implements Exception {
  const PlanFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Asks the server to write four questions about one desire.
///
/// Cheap and quota-free on purpose. It is a small call that precedes an
/// expensive one, and charging a month's allowance for a question set the user
/// then abandons would punish them for changing their mind. It is rate limited
/// instead, which catches a loop without punishing a person.
class PlanService {
  PlanService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<QuestionPlan> forDesire(String desire) async {
    try {
      final result = await _functions
          .httpsCallable(
            'planQuestions',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call<Map<Object?, Object?>>({'desire': desire.trim()});

      final plan = QuestionPlan.fromMap(Map<String, dynamic>.from(result.data));

      // Four is the contract, and the server enforces it with a schema. If it
      // ever comes back otherwise the flow cannot render, so this fails here
      // rather than halfway through a page of questions.
      if (!plan.isUsable) {
        throw const PlanFailed(
          'Maya could not shape that one into questions. Try rewording it.',
        );
      }

      return plan;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Maya: planning failed — ${error.code} ${error.message}');
      throw PlanFailed(
        humanMessage(
          error,
          fallback: 'Maya could not read that one. Try again in a moment.',
        ),
      );
    }
  }
}
