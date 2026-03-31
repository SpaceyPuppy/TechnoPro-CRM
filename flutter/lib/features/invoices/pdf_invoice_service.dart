import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../shared/models/models.dart';

// Brand colours mirrored in the PDF
const _kPrimaryBlue = PdfColor.fromInt(0xFF1D4ED8);
const _kDarkSlate = PdfColor.fromInt(0xFF0F172A);
const _kSlate600 = PdfColor.fromInt(0xFF475569);
const _kSlate200 = PdfColor.fromInt(0xFFE2E8F0);

class PdfInvoiceService {
  /// Build a PDF document for an invoice or quote.
  /// [customerName], [customerPhone], [customerEmail] are optional — include
  /// them when the caller has them available.
  static Future<pw.Document> buildInvoicePdf(
    InvoiceModel invoice,
    AppSettings settings, {
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) async {
    final doc = pw.Document();

    // Load logo from assets
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/image/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // Proceed without logo if asset missing
    }

    // Load Inter fonts from bundled assets (avoids network dependency)
    final ttfRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final ttfMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Medium.ttf'));
    final ttfBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));

    final theme = pw.ThemeData.withFont(
      base: ttfRegular,
      bold: ttfBold,
    );

    final isQuote = invoice.isQuote;
    final isPaid = invoice.isPaid;

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _buildHeader(invoice, settings, logo, isQuote),
          pw.SizedBox(height: 20),
          _buildAddressBlock(settings, customerName, customerPhone, customerEmail, invoice, ttfMedium, ttfBold),
          pw.SizedBox(height: 20),
          _buildLineItemsTable(invoice, ttfMedium, ttfBold),
          pw.SizedBox(height: 12),
          _buildTotals(invoice, settings, ttfMedium, ttfBold),
          if (!isQuote && invoice.payments.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildPayments(invoice, ttfMedium, ttfBold),
          ],
          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNotes(invoice.notes!, ttfMedium),
          ],
          if (isQuote) ...[
            pw.SizedBox(height: 16),
            _buildQuoteFooter(),
          ],
        ],
        // PAID watermark drawn as a background decorator
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: theme,
          buildBackground: isPaid ? (context) => _buildPaidWatermark() : null,
        ),
      ),
    );

    return doc;
  }

  // ---------------------------------------------------------------------------
  // Header: logo left, document type + number + date right
  // ---------------------------------------------------------------------------

  static pw.Widget _buildHeader(
    InvoiceModel invoice,
    AppSettings settings,
    pw.MemoryImage? logo,
    bool isQuote,
  ) {
    final docType = isQuote ? 'QUOTE' : 'INVOICE';
    final dateStr = _formatDate(invoice.createdAt);
    final statusStr = isQuote ? invoice.quoteStatusLabel : invoice.statusLabel;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Business info (left)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Image(logo, width: 120, height: 54, fit: pw.BoxFit.contain)
              else
                pw.Text(
                  settings.businessName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _kDarkSlate,
                  ),
                ),
              pw.SizedBox(height: 8),
              if (settings.businessName.isNotEmpty && logo != null)
                pw.Text(
                  settings.businessName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _kDarkSlate,
                  ),
                ),
              if (settings.businessAbn.isNotEmpty)
                pw.Text('ABN: ${settings.businessAbn}',
                    style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
              if (settings.businessAddress.isNotEmpty)
                pw.Text(settings.businessAddress,
                    style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
              if (settings.businessPhone.isNotEmpty || settings.businessEmail.isNotEmpty)
                pw.Text(
                  [
                    if (settings.businessPhone.isNotEmpty) settings.businessPhone,
                    if (settings.businessEmail.isNotEmpty) settings.businessEmail,
                  ].join('  ·  '),
                  style: const pw.TextStyle(fontSize: 9, color: _kSlate600),
                ),
            ],
          ),
        ),
        // Invoice meta (right)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              docType,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: _kPrimaryBlue,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              invoice.invoiceNumber,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _kDarkSlate,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text('Date: $dateStr',
                style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
            pw.SizedBox(height: 4),
            _statusBadge(statusStr, invoice),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statusBadge(String label, InvoiceModel invoice) {
    final PdfColor bg;
    final PdfColor fg;
    if (invoice.isPaid) {
      bg = const PdfColor.fromInt(0xFFDCFCE7);
      fg = const PdfColor.fromInt(0xFF16A34A);
    } else if (invoice.isVoid) {
      bg = const PdfColor.fromInt(0xFFF1F5F9);
      fg = _kSlate600;
    } else if (invoice.isQuote && invoice.quoteStatus == 'accepted') {
      bg = const PdfColor.fromInt(0xFFDCFCE7);
      fg = const PdfColor.fromInt(0xFF16A34A);
    } else if (invoice.isQuote && invoice.quoteStatus == 'declined') {
      bg = const PdfColor.fromInt(0xFFFEE2E2);
      fg = const PdfColor.fromInt(0xFFDC2626);
    } else {
      bg = const PdfColor.fromInt(0xFFDBEAFE);
      fg = _kPrimaryBlue;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Address block: business and bill-to side by side
  // ---------------------------------------------------------------------------

  static pw.Widget _buildAddressBlock(
    AppSettings settings,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    InvoiceModel invoice,
    pw.Font medium,
    pw.Font bold,
  ) {
    final hasCustomer = customerName != null ||
        customerPhone != null ||
        customerEmail != null;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (hasCustomer)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BILL TO',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _kSlate600)),
                  pw.SizedBox(height: 4),
                  if (customerName != null)
                    pw.Text(customerName,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _kDarkSlate)),
                  if (customerPhone != null)
                    pw.Text(customerPhone,
                        style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
                  if (customerEmail != null)
                    pw.Text(customerEmail,
                        style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
                ],
              ),
            ),
          if (invoice.ticketId != null)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('REFERENCE',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _kSlate600)),
                  pw.SizedBox(height: 4),
                  pw.Text('Ticket linked',
                      style: const pw.TextStyle(fontSize: 9, color: _kSlate600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Line items table
  // ---------------------------------------------------------------------------

  static pw.Widget _buildLineItemsTable(InvoiceModel invoice, pw.Font medium, pw.Font bold) {
    final headers = ['Description', 'Qty', 'Unit Price', 'Disc', 'Total'];
    final colWidths = [
      pw.FlexColumnWidth(4),
      pw.FlexColumnWidth(1),
      pw.FlexColumnWidth(1.5),
      pw.FlexColumnWidth(1),
      pw.FlexColumnWidth(1.5),
    ];

    pw.TextStyle headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );

    pw.TextStyle cellStyle = const pw.TextStyle(fontSize: 9, color: _kDarkSlate);
    pw.TextStyle subtleStyle = const pw.TextStyle(fontSize: 9, color: _kSlate600);

    return pw.Table(
      columnWidths: {
        0: colWidths[0],
        1: colWidths[1],
        2: colWidths[2],
        3: colWidths[3],
        4: colWidths[4],
      },
      border: null,
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _kDarkSlate),
          children: headers.asMap().entries.map((e) {
            final isNum = e.key > 0;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: pw.Text(
                e.value,
                style: headerStyle,
                textAlign: isNum ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...invoice.lineItems.asMap().entries.map((entry) {
          final i = entry.key;
          final li = entry.value;
          final isEven = i % 2 == 0;
          final discountStr = (double.tryParse(li.discount) ?? 0) > 0
              ? '${li.discount}%'
              : '—';

          return pw.TableRow(
            decoration: isEven
                ? null
                : pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF8FAFC)),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(li.description, style: cellStyle),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text('${li.quantity}',
                    style: cellStyle, textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text('\$${li.unitPrice}',
                    style: cellStyle, textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(discountStr,
                    style: subtleStyle, textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text('\$${li.total}',
                    style: cellStyle, textAlign: pw.TextAlign.right),
              ),
            ],
          );
        }),
        // Bottom border row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _kSlate200, width: 1)),
          ),
          children: List.generate(5, (_) => pw.SizedBox(height: 1)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Totals block
  // ---------------------------------------------------------------------------

  static pw.Widget _buildTotals(InvoiceModel invoice, AppSettings settings, pw.Font medium, pw.Font bold) {
    final gstRate = double.tryParse(invoice.taxRate) ?? 0;
    final gstLabel = gstRate > 0 ? 'GST (${gstRate.toStringAsFixed(0)}%)' : 'GST';

    return pw.Row(
      children: [
        pw.Spacer(),
        pw.SizedBox(
          width: 200,
          child: pw.Column(
            children: [
              _totalRow('Subtotal', '\$${invoice.subtotal}', bold: false, medium: medium),
              _totalRow(gstLabel, '\$${invoice.taxAmount}', bold: false, medium: medium),
              pw.Divider(color: _kSlate200, height: 1),
              pw.SizedBox(height: 4),
              _totalRow('TOTAL', '\$${invoice.total}', bold: true, medium: medium, large: true),
              if (!invoice.isQuote && (double.tryParse(invoice.amountPaid) ?? 0) > 0) ...[
                pw.SizedBox(height: 4),
                _totalRow('Amount Paid', '-\$${invoice.amountPaid}', bold: false, medium: medium, color: const PdfColor.fromInt(0xFF16A34A)),
                pw.Divider(color: _kSlate200, height: 1),
                pw.SizedBox(height: 4),
                _totalRow('Balance Due', '\$${invoice.balance}', bold: true, medium: medium),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    required bool bold,
    required pw.Font medium,
    bool large = false,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: large ? 12 : 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _kDarkSlate,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style.copyWith(color: bold ? _kDarkSlate : _kSlate600)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payments list
  // ---------------------------------------------------------------------------

  static pw.Widget _buildPayments(InvoiceModel invoice, pw.Font medium, pw.Font bold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('PAYMENTS',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _kSlate600)),
        pw.SizedBox(height: 4),
        pw.Divider(color: _kSlate200, height: 1),
        pw.SizedBox(height: 4),
        ...invoice.payments.map((p) {
          final typeLabel = p.isDeposit ? ' (Deposit)' : '';
          final methodLabel = _methodLabel(p.method);
          final ref = p.reference != null ? ' · ${p.reference}' : '';
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '$methodLabel$typeLabel · ${_formatDate(p.paidAt)}$ref',
                    style: const pw.TextStyle(fontSize: 9, color: _kSlate600),
                  ),
                ),
                pw.Text(
                  '\$${p.amount}',
                  style: const pw.TextStyle(fontSize: 9, color: _kDarkSlate),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  static pw.Widget _buildNotes(String notes, pw.Font medium) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('NOTES',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _kSlate600)),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9, color: _kDarkSlate)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quote validity footer
  // ---------------------------------------------------------------------------

  static pw.Widget _buildQuoteFooter() {
    return pw.Center(
      child: pw.Text(
        'This quote is valid for 30 days from the date of issue.',
        style: const pw.TextStyle(fontSize: 9, color: _kSlate600),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAID watermark (page background)
  // ---------------------------------------------------------------------------

  static pw.Widget _buildPaidWatermark() {
    return pw.Center(
      child: pw.Transform.rotate(
        angle: -0.5,
        child: pw.Text(
          'PAID',
          style: pw.TextStyle(
            fontSize: 120,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF16A34A).shade(0.08),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _methodLabel(String m) => switch (m) {
        'cash' => 'Cash',
        'card' => 'Card',
        'eftpos' => 'EFTPOS',
        'bank_transfer' => 'Bank Transfer',
        _ => 'Other',
      };
}
