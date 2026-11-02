import 'package:apexlytics/constants/legend_constants.dart';
import 'package:apexlytics/widgets/legend_asset_image.dart';
import 'package:apexlytics/widgets/legend_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCareerLegend', () {
    test('ignores case and surrounding whitespace', () {
      expect(isCareerLegend('Global'), isTrue);
      expect(isCareerLegend('global'), isTrue);
      expect(isCareerLegend(' GLOBAL '), isTrue);
    });

    test('is false for a legend', () {
      expect(isCareerLegend('Wraith'), isFalse);
      expect(isCareerLegend(''), isFalse);
    });

    test('the portrait key uses the career image for any casing', () {
      expect(legendImageKey('global'), 'career');
      expect(legendImageKey('GLOBAL'), 'career');
      expect(legendImageKey('Mad Maggie'), 'mad_maggie');
    });
  });

  group('legendIconAsset', () {
    test('a legend name in another case finds the same icon', () {
      expect(legendIconAsset('bloodhound'), legendIconAsset('Bloodhound'));
      expect(
        legendIconAsset('mad maggie'),
        'assets/legend_icons/Mad_Maggie_Icon.webp',
      );
    });

    test('an unrecognised name keeps its own spelling', () {
      expect(
        legendIconAsset('Some Legend'),
        'assets/legend_icons/Some_Legend_Icon.webp',
      );
    });
  });
}
