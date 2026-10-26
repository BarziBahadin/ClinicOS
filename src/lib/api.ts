import { captureAuthorization, client } from "./supabase";
import type { CommandName, Snapshot, Row } from "../domain/types";
import { WorkspaceSchema } from "../domain/workspace";
export class ApiError extends Error {
  constructor(
    message: string,
    readonly code?: string,
  ) {
    super(message);
  }
}
export async function rpc<T>(
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const authorization = await captureAuthorization();
  authorization.assertCurrent();
  const { data, error } = await client()
    .rpc(name, args)
    .setHeader("Authorization", `Bearer ${authorization.token}`);
  authorization.assertCurrent();
  if (error) throw new ApiError(error.message, error.code);
  return data as T;
}
export async function snapshot(): Promise<Snapshot> {
  return WorkspaceSchema.parse(await rpc<unknown>("workspace"));
}
export function execute(
  kind: CommandName,
  payload: Record<string, unknown>,
  requestId: string,
) {
  if (
    kind.startsWith("access.") ||
    kind.startsWith("care.") ||
    kind.startsWith("retention.")
  )
    return rpc<Row>("access_workflow", {
      kind,
      payload,
      request_id: requestId,
    });
  if (kind.startsWith("finance."))
    return rpc<Row>("finance_workflow", {
      kind,
      payload,
      request_id: requestId,
    });
  if (
    [
      "service.propose",
      "service.approve",
      "template.create",
      "template.approve",
      "document.create",
      "fact.record",
      "prescription.add",
      "contact.add",
      "contact.end",
      "contact.log",
      "performed.record",
      "performed.invoice",
      "package.expiry",
      "package.cancel",
      "stock.adjust",
      "availability.add",
      "resource.add",
      "appointment.reschedule",
      "supplier.create",
      "supplier.update",
      "product.create",
      "availability.end",
    ].includes(kind)
  )
    return rpc<Row>("workflow", { kind, payload, request_id: requestId });
  return rpc<Row>("command", { kind, payload, request_id: requestId });
}
export function clinicalRecord(patientId: string) {
  return rpc<{ encounters: Row[]; procedures: Row[]; facts?: Row[] }>(
    "clinical_record",
    {
      patient_id: patientId,
    },
  );
}
export async function exportAccounting() {
  return rpc<Row[]>("accounting_export");
}
export async function mediaUrl(mediaId: string) {
  return rpc<string>("media_access", { media_id: mediaId });
}
