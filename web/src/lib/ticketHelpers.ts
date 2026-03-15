import type { BadgeProps } from "@/components/ui/badge";

export function ticketStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    open: "Open",
    in_progress: "In Progress",
    waiting_parts: "Waiting Parts",
    waiting_customer: "Waiting Customer",
    resolved: "Resolved",
    closed: "Closed",
    cancelled: "Cancelled",
  };
  return labels[status] ?? status;
}

export function ticketStatusVariant(status: string): BadgeProps["variant"] {
  switch (status) {
    case "open":
      return "info";
    case "in_progress":
      return "warning";
    case "waiting_parts":
    case "waiting_customer":
      return "secondary";
    case "resolved":
      return "success";
    case "closed":
      return "outline";
    case "cancelled":
      return "destructive";
    default:
      return "secondary";
  }
}

export function ticketPriorityLabel(priority: string): string {
  const labels: Record<string, string> = {
    low: "Low",
    normal: "Normal",
    high: "High",
    urgent: "Urgent",
  };
  return labels[priority] ?? priority;
}

export function ticketPriorityVariant(priority: string): BadgeProps["variant"] {
  switch (priority) {
    case "low":
      return "outline";
    case "normal":
      return "secondary";
    case "high":
      return "warning";
    case "urgent":
      return "destructive";
    default:
      return "secondary";
  }
}
