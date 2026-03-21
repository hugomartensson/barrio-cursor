/**
 * Node 18: `grammy` pulls in `undici`, which expects global `File` (Node 20+).
 * This module must load before any import of `grammy`.
 */
import { Blob } from 'node:buffer';

type FileLikeOptions = { lastModified?: number; type?: string };
/** Subset of WHATWG BlobPart for Node typings without DOM lib */
type PolyfillBlobPart = ArrayBuffer | ArrayBufferView | Blob | string;

if (typeof globalThis.File === 'undefined') {
  class FilePolyfill extends Blob {
    readonly name: string;
    readonly lastModified: number;
    constructor(bits: PolyfillBlobPart[], name: string, options?: FileLikeOptions) {
      // Node's Blob ctor typings are stricter than WHATWG BlobPart; bits are compatible at runtime.
      super(bits as never, options);
      this.name = name;
      this.lastModified = options?.lastModified ?? Date.now();
    }
  }

  Object.defineProperty(globalThis, 'File', {
    value: FilePolyfill,
    writable: true,
    configurable: true,
  });
}

export {};
