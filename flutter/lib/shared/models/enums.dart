enum UserRole {
  technician('technician'),
  counter('counter'),
  manager('manager'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String s) =>
      UserRole.values.firstWhere((e) => e.value == s, orElse: () => UserRole.technician);
}

enum TicketStatus {
  open('open'),
  inProgress('in_progress'),
  waitingParts('waiting_parts'),
  waitingCustomer('waiting_customer'),
  resolved('resolved'),
  closed('closed'),
  cancelled('cancelled');

  const TicketStatus(this.value);
  final String value;

  static TicketStatus fromString(String s) =>
      TicketStatus.values.firstWhere((e) => e.value == s, orElse: () => TicketStatus.open);

  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.inProgress => 'In Progress',
        TicketStatus.waitingParts => 'Waiting Parts',
        TicketStatus.waitingCustomer => 'Waiting Customer',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
        TicketStatus.cancelled => 'Cancelled',
      };
}

enum TicketPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const TicketPriority(this.value);
  final String value;

  static TicketPriority fromString(String s) =>
      TicketPriority.values.firstWhere((e) => e.value == s, orElse: () => TicketPriority.normal);

  String get label => switch (this) {
        TicketPriority.low => 'Low',
        TicketPriority.normal => 'Normal',
        TicketPriority.high => 'High',
        TicketPriority.urgent => 'Urgent',
      };
}

enum TicketEventType {
  statusChange('status_change'),
  note('note'),
  assignment('assignment'),
  system('system');

  const TicketEventType(this.value);
  final String value;

  static TicketEventType fromString(String s) =>
      TicketEventType.values.firstWhere((e) => e.value == s, orElse: () => TicketEventType.note);
}

enum LineItemType {
  service('service'),
  part('part');

  const LineItemType(this.value);
  final String value;

  static LineItemType fromString(String s) =>
      LineItemType.values.firstWhere((e) => e.value == s, orElse: () => LineItemType.service);
}

enum InvoiceStatus {
  draft('draft'),
  open('open'),
  paid('paid'),
  void_('void');

  const InvoiceStatus(this.value);
  final String value;

  static InvoiceStatus fromString(String s) =>
      InvoiceStatus.values.firstWhere((e) => e.value == s, orElse: () => InvoiceStatus.draft);

  String get label => switch (this) {
        InvoiceStatus.draft => 'Draft',
        InvoiceStatus.open => 'Open',
        InvoiceStatus.paid => 'Paid',
        InvoiceStatus.void_ => 'Void',
      };
}

enum PaymentMethod {
  cash('cash'),
  card('card'),
  eftpos('eftpos'),
  bankTransfer('bank_transfer'),
  other('other');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod fromString(String s) =>
      PaymentMethod.values.firstWhere((e) => e.value == s, orElse: () => PaymentMethod.cash);

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.eftpos => 'EFTPOS',
        PaymentMethod.bankTransfer => 'Bank Transfer',
        PaymentMethod.other => 'Other',
      };
}
