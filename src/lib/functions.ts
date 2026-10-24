import { client } from "./supabase";
export async function invoke<T>(
  name: string,
  body: Record<string, unknown> | FormData,
): Promise<T> {
  const { data, error } = await client().functions.invoke(name, { body });
  if (error) {
    let message = error.message;
    try {
      const response = await error.context?.json();
      if (typeof response?.error === "string") message = response.error;
      else if (typeof response?.message === "string")
        message = response.message;
    } catch {}
    throw new Error(message);
  }
  if (data?.error) throw new Error(String(data.error));
  return data as T;
}
