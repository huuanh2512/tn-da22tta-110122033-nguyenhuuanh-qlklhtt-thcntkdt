/*
 * Fixed matching template smoke checklist.
 *
 * This file intentionally does not read .env. Run it against a started API with
 * explicit environment variables, for example:
 *   API_BASE_URL=http://127.0.0.1:3000/api/v1 node scripts/fixed-matching-template-smoke.js
 *
 * Manual data setup required:
 * - Active COURT_BOOKING and MATCHING fixed schedules.
 * - One READY TEAM_VS_TEAM or TEAM_FILL matching template.
 * - One RECRUITING matching template.
 * - A court with a known overlapping PENDING/CONFIRMED booking.
 *
 * Full manual runtime checklist:
 *   scripts/fixed-matching-runtime-checklist.md
 */

const checklist = [
  '1. MATCHING ACTIVE + readiness RECRUITING: generateBookingsForRange returns [] and creates no Booking, MatchingSession, or Payment.',
  '2. MATCHING ACTIVE + READY TEAM_VS_TEAM/TEAM_FILL within the 30-day window creates one Booking PENDING with fixed_schedule_id and is_fixed_schedule=true.',
  '3. READY occurrence creates exactly one MatchingSession OPEN unless full, with fixed_schedule_id, booking_id, booking_date/occurrenceDate, Team A/B snapshot, payment_policy, and fixed-template approved members only.',
  '4. TEAM_REPRESENTATIVES_SPLIT creates two PENDING payments attached to booking_id; host receives the remainder share.',
  '5. Running generate again for the same date range does not create duplicate Booking, MatchingSession, or Payment.',
  '6. PAUSED schedule is not returned by active scheduler and generateBookingsForRange creates no matching occurrence if called directly.',
  '7. exception_dates type CANCELLED or TEAM_UNAVAILABLE skips that date.',
  '8. Existing overlapping Booking PENDING/CONFIRMED causes the fixed matching occurrence to be skipped with a conflict warning.',
  '9. COURT_BOOKING fixed schedule still creates the old single Booking and host Payment path.',
  '10. INDIVIDUAL matching templates remain skipped in phase 2 unless a READY rule is later defined.',
  '11. Duplicate guards exist at DB level for fixed_schedule_id + date + start time + court occurrence keys.',
  '12. If payment creation fails after Booking/MatchingSession creation in fallback mode, Booking and pending Payments are cancelled and MatchingSession is marked CANCELLED.',
  '13. POST /fixed-schedule/:id/occurrences/:date/cancel cancels one generated MATCHING occurrence without cancelling the FixedSchedule.',
  '14. Cancel occurrence date X sets Booking PENDING to CANCELLED, MatchingSession OPEN/FULL to CANCELLED, and Payment PENDING to CANCELLED.',
  '15. Cancel occurrence date X upserts exception_dates with date X and type CANCELLED; running the generator again does not recreate date X.',
  '16. Cancel occurrence for a valid future date that has not been generated still upserts exception_dates and prevents later generation.',
  '17. Cancel occurrence with Payment SUCCESS logs/returns a manual-refund warning and does not set SUCCESS payments to REFUNDED.',
  '18. Cancel occurrence date X does not cancel bookings, matching sessions, or payments for other dates in the same FixedSchedule.',
  '19. PUT /fixed-schedule/:id/cancel for MATCHING sets the FixedSchedule to CANCELLED after syncing future occurrences.',
  '20. Cancel MATCHING series changes future Booking PENDING to CANCELLED and future MatchingSession OPEN/FULL to CANCELLED.',
  '21. Cancel MATCHING series changes future Payment PENDING to CANCELLED while leaving Payment SUCCESS unchanged with warning/summary.',
  '22. Cancel MATCHING series does not change past occurrences or COMPLETED bookings/sessions.',
  '23. COURT_BOOKING series cancellation still follows the existing future booking cancellation path.',
  '24. Phase 3 single occurrence cancel endpoint remains available after series cancel changes.',
  '25. Runtime create template: host/fixed side is kept on FixedSchedule; one-day public players are not added to FixedSchedule.members.',
  '26. Runtime readiness: when a template moves from RECRUITING to READY, generator creates occurrences for the 30-day window without waiting for cron.',
  '27. Runtime public list: GET /matching returns generated MatchingSession items by concrete day with matchingSessionId, bookingId, fixedScheduleId, occurrenceDate, startTime, endTime, and joinMode=ONE_DAY_ONLY.',
  '28. Runtime one-day join: POST /matching/:id/join changes only that MatchingSession; day A join does not add the user to day B or to FixedSchedule template.',
  '29. Runtime pause/resume: PAUSED blocks new occurrence generation; resume returns ACTIVE and does not restore manually cancelled occurrences.',
  '30. Runtime cancel occurrence: exception_dates receives the date and generator does not recreate it.',
  '31. Runtime cancel series: cancellationSummary is returned/displayed with cancelledBookings, cancelledMatchingSessions, cancelledPendingPayments, and successPayments.',
  '32. Permission: ordinary member cannot pause/resume/cancel series; host cannot leave through member leave endpoint; staff/admin are scoped by facility.',
  '33. Edge: joining a full Team A/B is rejected and leaves existing members/payments unchanged.',
  '34. Edge: generator skips RECRUITING, PAUSED, CANCELLED, and exception_dates occurrences.',
  '35. Window: a fixed matching date farther than 7 days but within 30 days is generated, hidden from the default matching list, and visible when bookingDate selects that exact day.',
  '36. Idempotency: approve-triggered generation and cron over the same 30-day window do not create duplicate Booking or MatchingSession records.',
  '37. Occurrence join INDIVIDUAL adds exactly one Team B member to one MatchingSession and never changes FixedSchedule.members.',
  '38. Occurrence join TEAM_REPRESENTATIVE stores Team B team name, representative, member count, and note only on that MatchingSession.',
  '39. Team B safe mode rejects mixing individual members with a team representative and rejects a second representative.',
  '40. Joining occurrence date A does not change occurrence date B from the same FixedSchedule.',
  '41. READY template with two future occurrences: Team B representative leave marks member LEFT, readiness becomes RECRUITING, future PENDING Booking/MatchingSession/Payment are CANCELLED, SUCCESS payments are kept with warning, and past/COMPLETED occurrences are unchanged.'
];

for (const item of checklist) {
  console.log(item);
}

console.log('\nFull manual report: scripts/fixed-matching-runtime-checklist.md');
