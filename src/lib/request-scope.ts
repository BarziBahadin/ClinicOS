import { useLayoutEffect, useRef } from "react";
/** Capture once per request; invalid after unmount or a change of patient/session scope. */
export function useRequestScope(scope = "") {
  const generation = useRef(0);
  useLayoutEffect(() => {
    generation.current++;
    return () => {
      generation.current++;
    };
  }, [scope]);
  return () => {
    const request = generation.current;
    return () => request === generation.current;
  };
}
