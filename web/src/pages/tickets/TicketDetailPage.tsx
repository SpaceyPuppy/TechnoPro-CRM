import { useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { ArrowLeft, Edit, FileText, Paperclip, Trash2, Image, File } from "lucide-react";
import { toast } from "sonner";
import { ticketsApi } from "@/api/tickets";
import { invoicesApi } from "@/api/invoices";
import { attachmentsApi } from "@/api/attachments";
import { TicketStatus } from "@technopro/shared";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Separator } from "@/components/ui/separator";
import {
  ticketStatusVariant,
  ticketStatusLabel,
  ticketPriorityVariant,
  ticketPriorityLabel,
} from "@/lib/ticketHelpers";

export function TicketDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [note, setNote] = useState("");

  const { data: ticketData, isLoading } = useQuery({
    queryKey: ["tickets", id],
    queryFn: () => ticketsApi.get(id!),
  });

  const { data: eventsData } = useQuery({
    queryKey: ["tickets", id, "events"],
    queryFn: () => ticketsApi.getEvents(id!),
    enabled: !!id,
  });

  const statusMutation = useMutation({
    mutationFn: (status: TicketStatus) => ticketsApi.update(id!, { status }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tickets"] });
      toast.success("Status updated");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const noteMutation = useMutation({
    mutationFn: (content: string) => ticketsApi.addNote(id!, content),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tickets", id, "events"] });
      setNote("");
      toast.success("Note added");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const { data: invoicesData } = useQuery({
    queryKey: ["invoices", { ticketId: id }],
    queryFn: () => invoicesApi.list({ ticketId: id }),
    enabled: !!id,
  });

  const { data: attachmentsData } = useQuery({
    queryKey: ["tickets", id, "attachments"],
    queryFn: () => attachmentsApi.list(id!),
    enabled: !!id,
  });

  const fileInputRef = useRef<HTMLInputElement>(null);

  const uploadMutation = useMutation({
    mutationFn: (file: File) => attachmentsApi.upload(id!, file),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tickets", id, "attachments"] });
      toast.success("File uploaded");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const deleteAttachmentMutation = useMutation({
    mutationFn: (attachmentId: string) => attachmentsApi.delete(id!, attachmentId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["tickets", id, "attachments"] });
      toast.success("Attachment deleted");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const ticketInvoice = invoicesData?.data[0] ?? null;

  if (isLoading) return <div className="p-6 text-sm text-muted-foreground">Loading...</div>;
  if (!ticketData) return <div className="p-6 text-sm text-destructive">Ticket not found.</div>;

  const ticket = ticketData.data;

  return (
    <div className="p-6 space-y-6 max-w-3xl">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link to="/tickets">
            <ArrowLeft size={16} />
          </Link>
        </Button>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-xs font-mono text-muted-foreground">{ticket.ticketNumber}</span>
            <Badge variant={ticketStatusVariant(ticket.status)}>
              {ticketStatusLabel(ticket.status)}
            </Badge>
            <Badge variant={ticketPriorityVariant(ticket.priority)}>
              {ticketPriorityLabel(ticket.priority)}
            </Badge>
          </div>
          <h1 className="text-xl font-semibold mt-1 truncate">{ticket.summary}</h1>
        </div>
        <Button variant="outline" size="sm" asChild>
          <Link to={`/tickets/${id}/edit`}>
            <Edit size={14} />
            Edit
          </Link>
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Update Status</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-wrap gap-2">
          {Object.values(TicketStatus).map((s) => (
            <Button
              key={s}
              variant={ticket.status === s ? "default" : "outline"}
              size="sm"
              disabled={ticket.status === s || statusMutation.isPending}
              onClick={() => statusMutation.mutate(s)}
            >
              {ticketStatusLabel(s)}
            </Button>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Details</CardTitle>
        </CardHeader>
        <CardContent className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <p className="text-muted-foreground">Customer</p>
            <Link to={`/customers/${ticket.customerId}`} className="text-primary hover:underline">
              View customer
            </Link>
          </div>
          {ticket.dueDate && (
            <div>
              <p className="text-muted-foreground">Due</p>
              <p>{new Date(ticket.dueDate).toLocaleDateString()}</p>
            </div>
          )}
          {ticket.description && (
            <div className="col-span-2">
              <p className="text-muted-foreground">Description</p>
              <p className="whitespace-pre-wrap mt-1">{ticket.description}</p>
            </div>
          )}
          {ticket.diagnosis && (
            <div className="col-span-2">
              <p className="text-muted-foreground">Diagnosis</p>
              <p className="whitespace-pre-wrap mt-1">{ticket.diagnosis}</p>
            </div>
          )}
          {ticket.resolution && (
            <div className="col-span-2">
              <p className="text-muted-foreground">Resolution</p>
              <p className="whitespace-pre-wrap mt-1">{ticket.resolution}</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Invoice */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Invoice</CardTitle>
            {!ticketInvoice && (
              <Button size="sm" onClick={() => navigate(`/invoices/new?ticketId=${id}`)}>
                <FileText size={14} />
                Create Invoice
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {ticketInvoice ? (
            <div className="flex items-center justify-between text-sm">
              <div className="space-y-1">
                <p className="font-mono font-medium">{ticketInvoice.invoiceNumber}</p>
                <p className="text-muted-foreground capitalize">{ticketInvoice.status}</p>
              </div>
              <div className="text-right space-y-1">
                <p className="font-semibold">${ticketInvoice.total}</p>
                {parseFloat(ticketInvoice.balance) > 0 && (
                  <p className="text-xs text-destructive">Balance: ${ticketInvoice.balance}</p>
                )}
              </div>
              <Button variant="outline" size="sm" asChild>
                <Link to={`/invoices/${ticketInvoice.id}?from=ticket`}>View Invoice</Link>
              </Button>
            </div>
          ) : (
            <p className="text-sm text-muted-foreground">No invoice yet.</p>
          )}
        </CardContent>
      </Card>

      {/* Attachments */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Attachments</CardTitle>
            <Button
              size="sm"
              variant="outline"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploadMutation.isPending}
            >
              <Paperclip size={14} />
              {uploadMutation.isPending ? "Uploading..." : "Add File"}
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              className="hidden"
              accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.txt"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) uploadMutation.mutate(file);
                e.target.value = "";
              }}
            />
          </div>
        </CardHeader>
        <CardContent>
          {(!attachmentsData || attachmentsData.data.length === 0) && !uploadMutation.isPending && (
            <p className="text-sm text-muted-foreground">No attachments yet.</p>
          )}
          <div className="space-y-2">
            {attachmentsData?.data.map((att) => {
              const isImage = att.mimeType.startsWith("image/");
              const sizeKb = (att.fileSize / 1024).toFixed(0);
              const fileUrl = attachmentsApi.getUrl(att.filePath);
              return (
                <div key={att.id} className="flex items-center gap-3 text-sm">
                  {isImage ? (
                    <Image size={16} className="text-muted-foreground shrink-0" />
                  ) : (
                    <File size={16} className="text-muted-foreground shrink-0" />
                  )}
                  <a
                    href={fileUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="flex-1 truncate text-primary hover:underline"
                  >
                    {att.fileName}
                  </a>
                  <span className="text-xs text-muted-foreground shrink-0">{sizeKb} KB</span>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-7 w-7 shrink-0 text-muted-foreground hover:text-destructive"
                    onClick={() => deleteAttachmentMutation.mutate(att.id)}
                    disabled={deleteAttachmentMutation.isPending}
                  >
                    <Trash2 size={13} />
                  </Button>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      <div>
        <h2 className="font-semibold mb-3">History</h2>
        <div className="space-y-2">
          {eventsData?.data.map((ev) => (
            <div key={ev.id} className="flex gap-3 text-sm">
              <div className="w-28 shrink-0 text-xs text-muted-foreground pt-0.5">
                {new Date(ev.createdAt).toLocaleString([], {
                  dateStyle: "short",
                  timeStyle: "short",
                })}
              </div>
              <div>
                <span className="capitalize text-muted-foreground">
                  {ev.eventType.replace("_", " ")}
                </span>
                {ev.content && <p className="mt-0.5 whitespace-pre-wrap">{ev.content}</p>}
              </div>
            </div>
          ))}
          {(!eventsData || eventsData.data.length === 0) && (
            <p className="text-sm text-muted-foreground">No events yet.</p>
          )}
        </div>
        <Separator className="my-4" />
        <div className="space-y-2">
          <Textarea
            placeholder="Add a note..."
            rows={3}
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
          <Button
            size="sm"
            disabled={!note.trim() || noteMutation.isPending}
            onClick={() => noteMutation.mutate(note)}
          >
            Add Note
          </Button>
        </div>
      </div>
    </div>
  );
}
