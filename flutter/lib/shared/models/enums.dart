import 'package:flutter/material.dart';

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

extension UserRolePermissions on UserRole {
  bool get canManage => this == UserRole.manager || this == UserRole.admin;
  bool get canCounter => this == UserRole.counter || canManage;
  bool get canTech => this == UserRole.technician || canManage;
  bool get isAdmin => this == UserRole.admin;
}

enum TicketStatus {
  new_('new'),
  triage('triage'),
  scheduled('scheduled'),
  inProgress('in_progress'),
  awaitingCustomer('awaiting_customer'),
  awaitingParts('awaiting_parts'),
  ready('ready'),
  resolved('resolved'),
  closed('closed'),
  cancelled('cancelled');

  const TicketStatus(this.value);
  final String value;

  static TicketStatus fromString(String value) {
    final migrated = switch (value) {
      'open' => 'new',
      'waiting_customer' => 'awaiting_customer',
      'waiting_parts' => 'awaiting_parts',
      _ => value,
    };
    return TicketStatus.values.firstWhere(
      (status) => status.value == migrated,
      orElse: () => TicketStatus.new_,
    );
  }

  String get label => switch (this) {
        TicketStatus.new_ => 'New',
        TicketStatus.triage => 'Triage',
        TicketStatus.scheduled => 'Scheduled',
        TicketStatus.inProgress => 'In Progress',
        TicketStatus.awaitingCustomer => 'Awaiting Customer',
        TicketStatus.awaitingParts => 'Awaiting Parts',
        TicketStatus.ready => 'Ready',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
        TicketStatus.cancelled => 'Cancelled',
      };

  // Primary color for the status
  Color get color {
    return switch (this) {
      TicketStatus.new_ => const Color(0xFF3B82F6), // Blue
      TicketStatus.triage => const Color(0xFF0EA5E9), // Sky
      TicketStatus.scheduled => const Color(0xFF6366F1), // Indigo
      TicketStatus.inProgress => const Color(0xFF8B5CF6), // Purple
      TicketStatus.awaitingCustomer => const Color(0xFFEC4899), // Pink
      TicketStatus.awaitingParts => const Color(0xFFF59E0B), // Amber
      TicketStatus.ready => const Color(0xFF14B8A6), // Teal
      TicketStatus.resolved => const Color(0xFF10B981), // Emerald
      TicketStatus.closed => const Color(0xFF64748B), // Slate
      TicketStatus.cancelled => const Color(0xFFEF4444), // Red
    };
  }

  // Light background for the status card
  Color get bgColor {
    return switch (this) {
      TicketStatus.new_ => const Color(0xFFEFF6FF), // Blue 50
      TicketStatus.triage => const Color(0xFFF0F9FF), // Sky 50
      TicketStatus.scheduled => const Color(0xFFEEF2FF), // Indigo 50
      TicketStatus.inProgress => const Color(0xFFFAF5FF), // Purple 50
      TicketStatus.awaitingCustomer => const Color(0xFFFCE7F3), // Pink 50
      TicketStatus.awaitingParts => const Color(0xFFFEFCE8), // Amber 50
      TicketStatus.ready => const Color(0xFFF0FDFA), // Teal 50
      TicketStatus.resolved => const Color(0xFFECFDF5), // Emerald 50
      TicketStatus.closed => const Color(0xFFF1F5F9), // Slate 50
      TicketStatus.cancelled => const Color(0xFFFEE2E2), // Red 50
    };
  }
}

enum TicketType {
  repair('repair'),
  onsite('onsite'),
  remote('remote');

  const TicketType(this.value);
  final String value;

  static TicketType fromString(String value) => TicketType.values.firstWhere(
        (type) => type.value == value,
        orElse: () => TicketType.repair,
      );

  String get label => switch (this) {
        TicketType.repair => 'Repair',
        TicketType.onsite => 'Onsite',
        TicketType.remote => 'Remote',
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
