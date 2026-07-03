/// Maps server call-end signals to user-facing copy for the caller.
String callerMessageForCallEndSignal(
  Map<String, dynamic> payload, {
  required bool hadRemoteParticipant,
}) {
  final action = payload['action']?.toString();
  final reason = payload['reason']?.toString();

  if (action == 'declined' || reason == 'declined') {
    return 'Call declined';
  }
  if (reason == 'no_answer') {
    return 'No answer';
  }
  if (hadRemoteParticipant) {
    return 'The call ended';
  }
  return 'They couldn\'t take the call (declined, busy, or offline).';
}
