export interface NanouiBridge {
  /**
   * Calls a bound Zig method exposed by App.bind via IPC.
   * @param method The service method, e.g. "storage.probeDisks"
   * @param args Arguments passed to the Zig method
   */
  call: <T = any>(method: string, ...args: any[]) => Promise<T>;

  /**
   * Subscribes to events emitted from Zig via nanoui.
   * @param event The event name
   * @param callback Function called when the event is emitted
   * @returns Unsubscribe function
   */
  on: <T = any>(event: string, callback: (payload: T) => void) => () => void;

  /**
   * Subscribes once to an event emitted from Zig.
   */
  once: <T = any>(event: string, callback: (payload: T) => void) => () => void;
}

declare global {
  interface Window {
    nanoui?: NanouiBridge;
  }
}
