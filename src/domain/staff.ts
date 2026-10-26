import type { Membership, Role } from "./types";
export function hasRole(member: Membership, role: Role) {
  return (
    member.role === role || Boolean(member.additional_roles?.includes(role))
  );
}
