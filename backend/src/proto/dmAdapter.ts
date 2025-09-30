import type { bilibili as BilibiliNS } from './dm.d';
import dmRoot from './dm.js';

export type DmSegMobileReply = BilibiliNS.community.service.dm.v1.DmSegMobileReply;

export function decodeDmSegMobileReply(buffer: ArrayBuffer | Uint8Array): DmSegMobileReply {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  // @ts-ignore
  const Dec = (dmRoot as any)?.bilibili?.community?.service?.dm?.v1?.DmSegMobileReply;
  if (!Dec || typeof Dec.decode !== 'function') {
    throw new Error('DmSegMobileReply decoder is not available in compiled proto');
  }
  const message = Dec.decode(bytes);
  return message as DmSegMobileReply;
}

export const types = dmRoot; // 可选暴露全部命名空间，方便调试需要时访问 