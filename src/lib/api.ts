import { client } from "./supabase";
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
async function rpc<T>(
  name: string,
  args: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await client().rpc(name, args);
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
  return rpc<Row>("command", { kind, payload, request_id: requestId });
}
export function clinicalRecord(patientId: string) {
  return rpc<{ encounters: Row[]; procedures: Row[] }>("clinical_record", {
    patient_id: patientId,
  });
}
export async function exportAccounting() {
  return rpc<Row[]>("accounting_export");
}
export async function mediaUrl(mediaId: string) {
  return rpc<string>("media_access", { media_id: mediaId });
}
