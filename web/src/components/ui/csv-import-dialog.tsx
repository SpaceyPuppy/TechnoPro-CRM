import { useRef, useState } from "react";
import { Upload, X, AlertCircle, CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export interface CsvColumn {
  key: string;
  label: string;
  required?: boolean;
}

export interface ImportResult {
  imported: number;
  skipped: number;
  errors: Array<{ row: number; reason: string }>;
}

interface Props {
  title: string;
  columns: CsvColumn[];
  exampleRow: string;
  onImport: (rows: Record<string, string>[]) => Promise<ImportResult>;
  onClose: () => void;
}

function parseCsv(text: string): string[][] {
  const lines = text.trim().split(/\r?\n/);
  return lines.map((line) => {
    const cells: string[] = [];
    let cur = "";
    let inQuotes = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]!;
      if (ch === '"') {
        if (inQuotes && line[i + 1] === '"') { cur += '"'; i++; }
        else { inQuotes = !inQuotes; }
      } else if (ch === "," && !inQuotes) {
        cells.push(cur.trim()); cur = "";
      } else {
        cur += ch;
      }
    }
    cells.push(cur.trim());
    return cells;
  });
}

export function CsvImportDialog({ title, columns, exampleRow, onImport, onClose }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [rows, setRows] = useState<Record<string, string>[] | null>(null);
  const [parseError, setParseError] = useState<string | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [isImporting, setIsImporting] = useState(false);

  function handleFile(file: File) {
    setParseError(null);
    setRows(null);
    setResult(null);

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const text = e.target?.result as string;
        const parsed = parseCsv(text);
        if (parsed.length < 2) { setParseError("File must have a header row and at least one data row."); return; }

        const headers = parsed[0]!.map((h) => h.toLowerCase().trim());
        const dataRows = parsed.slice(1).filter((r) => r.some((c) => c.length > 0));

        // Map CSV headers to column keys (flexible matching)
        const colMap: Record<string, number> = {};
        for (const col of columns) {
          const idx = headers.findIndex(
            (h) => h === col.key.toLowerCase() || h === col.label.toLowerCase(),
          );
          if (idx === -1 && col.required) {
            setParseError(`Required column "${col.label}" not found in CSV headers: ${headers.join(", ")}`);
            return;
          }
          if (idx !== -1) colMap[col.key] = idx;
        }

        const mapped = dataRows.map((r) => {
          const obj: Record<string, string> = {};
          for (const col of columns) {
            const idx = colMap[col.key];
            obj[col.key] = idx !== undefined ? (r[idx] ?? "") : "";
          }
          return obj;
        });

        setRows(mapped);
      } catch {
        setParseError("Failed to parse CSV file.");
      }
    };
    reader.readAsText(file);
  }

  async function handleImport() {
    if (!rows) return;
    setIsImporting(true);
    try {
      const res = await onImport(rows);
      setResult(res);
    } catch (err) {
      setParseError(err instanceof Error ? err.message : "Import failed");
    } finally {
      setIsImporting(false);
    }
  }

  const previewRows = rows?.slice(0, 5);

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-2xl p-6 space-y-4 max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold">{title}</h2>
          <Button variant="ghost" size="icon" className="h-6 w-6" onClick={onClose}>
            <X size={16} />
          </Button>
        </div>

        {/* Format guide */}
        <div className="bg-muted/40 rounded-md p-3 text-xs space-y-1">
          <p className="font-medium text-muted-foreground">Expected columns:</p>
          <p className="font-mono">
            {columns.map((c) => (c.required ? c.key : `[${c.key}]`)).join(",")}
          </p>
          <p className="font-medium text-muted-foreground pt-1">Example:</p>
          <p className="font-mono">{columns.map((c) => c.key).join(",")}</p>
          <p className="font-mono text-muted-foreground">{exampleRow}</p>
          <p className="text-muted-foreground pt-1">Required columns are unbracketed. Optional columns are [bracketed].</p>
        </div>

        {/* File picker */}
        {!result && (
          <div>
            <input
              ref={inputRef}
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
            />
            <Button variant="outline" size="sm" onClick={() => inputRef.current?.click()}>
              <Upload size={14} />
              {rows ? "Change file" : "Choose CSV file"}
            </Button>
            {rows && (
              <span className="ml-3 text-sm text-muted-foreground">{rows.length} rows ready to import</span>
            )}
          </div>
        )}

        {parseError && (
          <div className="flex items-start gap-2 text-sm text-destructive">
            <AlertCircle size={15} className="mt-0.5 shrink-0" />
            {parseError}
          </div>
        )}

        {/* Preview table */}
        {previewRows && previewRows.length > 0 && !result && (
          <div>
            <p className="text-xs font-medium text-muted-foreground mb-2">
              Preview (first {previewRows.length} of {rows!.length} rows):
            </p>
            <div className="rounded-md border overflow-x-auto">
              <table className="w-full text-xs">
                <thead className="bg-muted/50">
                  <tr>
                    {columns.map((c) => (
                      <th key={c.key} className="px-3 py-2 text-left font-medium text-muted-foreground">
                        {c.label}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {previewRows.map((row, i) => (
                    <tr key={i}>
                      {columns.map((c) => (
                        <td key={c.key} className="px-3 py-2 max-w-[200px] truncate">
                          {row[c.key] || <span className="text-muted-foreground">—</span>}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Result */}
        {result && (
          <div className="space-y-3">
            <div className="flex items-center gap-2 text-sm">
              <CheckCircle2 size={16} className="text-green-600 shrink-0" />
              <span>
                <strong>{result.imported}</strong> imported
                {result.skipped > 0 && <>, <strong>{result.skipped}</strong> skipped</>}
              </span>
            </div>
            {result.errors.length > 0 && (
              <div className="rounded-md border border-destructive/40 bg-destructive/5 p-3 space-y-1 max-h-40 overflow-y-auto">
                <p className="text-xs font-medium text-destructive">Errors:</p>
                {result.errors.slice(0, 20).map((e) => (
                  <p key={e.row} className="text-xs text-muted-foreground">
                    Row {e.row}: {e.reason}
                  </p>
                ))}
                {result.errors.length > 20 && (
                  <p className="text-xs text-muted-foreground">… and {result.errors.length - 20} more</p>
                )}
              </div>
            )}
          </div>
        )}

        <div className="flex gap-2 pt-2">
          {result ? (
            <Button onClick={onClose} className="flex-1">Done</Button>
          ) : (
            <>
              <Button variant="outline" onClick={onClose} className="flex-1">Cancel</Button>
              <Button
                onClick={handleImport}
                disabled={!rows || rows.length === 0 || isImporting}
                className="flex-1"
              >
                {isImporting ? "Importing…" : `Import ${rows?.length ?? 0} rows`}
              </Button>
            </>
          )}
        </div>
      </Card>
    </div>
  );
}
