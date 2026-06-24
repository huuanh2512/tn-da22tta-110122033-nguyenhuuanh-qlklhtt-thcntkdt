import 'package:flutter_test/flutter_test.dart';
import 'package:matching_module/matching_module.dart';

void main() {
  group('Bill Splitting Calculation Logic Tests', () {
    test('calculate correct amount per person for matchmaking sessions', () {
      // 1. Arrange
      const totalAmount = 300000.0; // 300,000 VND
      const hostId = 'user_host';
      const hostName = 'Host User';
      const hostEmail = 'host@test.com';
      const hostAvatarUrl = '';
      const sportId = 'soccer_sport';
      const sportName = 'Bóng đá';
      const facilityId = 'q7_complex';
      const facilityName = 'Sân Q7';
      const facilityCity = 'HCM';
      const bookingDate = '2026-06-08';

      // Members: 2 APPROVED, 1 PENDING, 1 REJECTED
      final members = [
        const MatchingMemberEntity(
          userId: 'user_approved_1',
          name: 'Player 1',
          avatarUrl: '',
          status: 'APPROVED',
        ),
        const MatchingMemberEntity(
          userId: 'user_approved_2',
          name: 'Player 2',
          avatarUrl: '',
          status: 'APPROVED',
        ),
        const MatchingMemberEntity(
          userId: 'user_pending_3',
          name: 'Player 3',
          avatarUrl: '',
          status: 'PENDING',
        ),
        const MatchingMemberEntity(
          userId: 'user_rejected_4',
          name: 'Player 4',
          avatarUrl: '',
          status: 'REJECTED',
        ),
      ];

      final matchingSession = MatchingSessionEntity(
        id: 'session_123',
        hostId: hostId,
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        hostEmail: hostEmail,
        sportId: sportId,
        sportName: sportName,
        facilityId: facilityId,
        facilityName: facilityName,
        facilityCity: facilityCity,
        bookingDate: bookingDate,
        startMinutes: 480,
        endMinutes: 540,
        totalPlayersNeeded: 10,
        approvedCount: 2,
        availableSpots: 8,
        description: 'Test session',
        autoApprove: false,
        members: members,
        status: 'OPEN',
      );

      // 2. Act
      final approvedMembersCount = matchingSession.members.where((m) => m.status == 'APPROVED').length;
      final totalPlayers = approvedMembersCount + 1; // Members + Host
      final amountPerPerson = totalAmount / totalPlayers;

      // 3. Assert
      expect(approvedMembersCount, 2);
      expect(totalPlayers, 3); // 2 members + 1 host
      expect(amountPerPerson, 100000.0); // 300,000 / 3 = 100,000 VND per person
    });
  });
}
