import 'package:flutter_test/flutter_test.dart';
import 'package:technopro_crm/shared/models/models.dart';

void main() {
  AppSettings settings({String businessName = 'First Choice Phone Repair'}) =>
      AppSettings(
        businessName: businessName,
        businessAbn: '',
        businessAddress: '',
        businessPhone: '',
        businessEmail: '',
        gstRate: '10.00',
        labourRate: '75.00',
        invoiceNotes: '',
      );

  test('PDF settings allow blank optional branding fields', () {
    expect(settings().missingRequiredPdfBusinessSetting, isNull);
  });

  test('PDF settings require a business name', () {
    expect(
      settings(businessName: '  ').missingRequiredPdfBusinessSetting,
      'Business Name',
    );
  });
}
