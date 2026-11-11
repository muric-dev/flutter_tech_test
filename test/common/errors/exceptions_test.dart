import 'package:cabina/common/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CabinaException', () {
    test('messageOf returns message for CabinaException subclasses', () {
      expect(
        CabinaException.messageOf(const NetworkException('connection lost')),
        'connection lost',
      );
      expect(
        CabinaException.messageOf(const ApiException('bad request')),
        'bad request',
      );
      expect(
        CabinaException.messageOf(const FeedParseException('malformed xml')),
        'malformed xml',
      );
      expect(
        CabinaException.messageOf(const CabinaPlayerException('audio error')),
        'audio error',
      );
      expect(
        CabinaException.messageOf(const StorageException('disk full')),
        'disk full',
      );
    });

    test('AICompanionException offers no retry unless it says so', () {
      expect(const AICompanionException('not available').canRetry, isFalse);
      expect(
        const AICompanionException('no connection', canRetry: true).canRetry,
        isTrue,
      );
    });

    test(
      'messageOf returns fallbackMessage for non-CabinaException objects',
      () {
        expect(
          CabinaException.messageOf(StateError('unexpected state')),
          CabinaException.fallbackMessage,
        );
        expect(
          CabinaException.messageOf(Exception('generic error')),
          CabinaException.fallbackMessage,
        );
        expect(
          CabinaException.messageOf('string error'),
          CabinaException.fallbackMessage,
        );
      },
    );
  });
}
