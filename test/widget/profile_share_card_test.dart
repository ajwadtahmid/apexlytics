import 'package:apexlytics/screens/search/profile_card_screen.dart';
import 'package:apexlytics/widgets/profile_share_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  final stats = buildStats(
    name: 'Tester',
    uid: '1010712222499',
    rank: 'Diamond',
    rankScore: 11250,
    legendStats: [
      buildLegend(
        name: 'Global',
        trackers: [buildTracker(key: 'kills', value: 27000)],
      ),
      buildLegend(
        name: 'Wraith',
        trackers: [buildTracker(key: 'kills', value: 500)],
      ),
      buildLegend(
        name: 'Horizon',
        trackers: [
          buildTracker(key: 'kills', value: 2400),
          buildTracker(key: 'damage', value: 900000),
        ],
      ),
    ],
  );

  Widget card([ProfileCardOptions options = const ProfileCardOptions()]) =>
      Scaffold(
        body: ProfileShareCard(
          stats: stats,
          playerName: 'Tester',
          options: options,
        ),
      );

  group('the card', () {
    testWidgets('shows every box by default, and no UID', (tester) async {
      await pump(tester, card());
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('PC'), findsOneWidget);
      expect(find.text('Diamond'), findsOneWidget);
      expect(find.text('RANK'), findsOneWidget);
      expect(find.textContaining('11,250'), findsNothing);
      expect(find.text('Apex profile'), findsNothing);
      expect(find.text('Horizon'), findsOneWidget);
      expect(find.text('2,400'), findsOneWidget);
      expect(find.text('900,000'), findsOneWidget);
      expect(find.textContaining('1010712222499'), findsNothing);
    });

    testWidgets('says what the card is when the name is hidden', (
      tester,
    ) async {
      await pump(tester, Scaffold(body: ProfileShareCard(stats: stats)));
      expect(find.text('Apex profile'), findsOneWidget);
      expect(find.text('Tester'), findsNothing);
    });

    testWidgets('prints the UID only when asked', (tester) async {
      await pump(tester, card(const ProfileCardOptions(showUid: true)));
      expect(find.text('UID: 1010712222499'), findsOneWidget);
    });

    testWidgets('leaves off a box that is switched off, not level', (
      tester,
    ) async {
      await pump(
        tester,
        card(const ProfileCardOptions(stats: {ProfileCardStat.kills})),
      );
      expect(find.text('Diamond'), findsNothing);
      expect(find.text('900,000'), findsNothing);
      expect(find.text('2,400'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('PC'), findsOneWidget);
    });

    testWidgets('a favourite legend replaces the top one, with its figures', (
      tester,
    ) async {
      await pump(
        tester,
        card(const ProfileCardOptions(favoriteLegend: 'Wraith')),
      );
      expect(find.text('Wraith'), findsOneWidget);
      expect(find.text('FAVORITE LEGEND'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('2,400'), findsNothing);
    });

    testWidgets('a legend with no figures shows a dash, not a zero', (
      tester,
    ) async {
      await pump(
        tester,
        card(const ProfileCardOptions(favoriteLegend: 'Bloodhound')),
      );
      expect(find.text('—'), findsNWidgets(2));
    });
  });

  test('top legend ignores the career entry and legends without kills', () {
    expect(topLegendByKills(buildStats()), isNull);
    expect(topLegendByKills(stats)!.name, 'Horizon');
  });

  group('the screen', () {
    testWidgets('UID is off to start with and can be switched on', (
      tester,
    ) async {
      await pump(tester, ProfileCardScreen(stats: stats));
      expect(find.textContaining('UID: 1010712222499'), findsNothing);
      await tester.tap(find.text('Show UID'));
      await tester.pump();
      expect(find.text('UID: 1010712222499'), findsOneWidget);
    });

    testWidgets('the UID switch sits under the name switch', (tester) async {
      await pump(tester, ProfileCardScreen(stats: stats));
      expect(
        tester.getTopLeft(find.text('Show UID')).dy,
        greaterThan(tester.getTopLeft(find.text('Show their name')).dy),
      );
    });

    testWidgets('a chip takes a box off the card', (tester) async {
      await pump(tester, ProfileCardScreen(stats: stats));
      expect(find.text('900,000'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Damage'));
      await tester.pump();
      expect(find.text('900,000'), findsNothing);
    });

    testWidgets('picks a favourite legend from the list', (tester) async {
      await pump(tester, ProfileCardScreen(stats: stats));
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wraith').last);
      await tester.pumpAndSettle();
      expect(find.text('FAVORITE LEGEND'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('names the owner of a looked-up profile', (tester) async {
      await pump(tester, ProfileCardScreen(stats: stats));
      expect(find.text('Show their name'), findsOneWidget);
      await pump(tester, ProfileCardScreen(stats: stats, mine: true));
      expect(find.text('Show my name'), findsOneWidget);
    });
  });
}
