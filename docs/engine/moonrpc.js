function _M0TP312moonbitstack8moonhttp6header6Header(param0, param1) {
  this.name = param0;
  this.value = param1;
}
function $make_array_len_and_init(a, b) {
  const arr = new Array(a);
  arr.fill(b);
  return arr;
}
function $oob() {
  throw new Error("Index out of bounds");
}
class $PanicError extends Error {}
function $panic() {
  throw new $PanicError();
}
function _M0TPB13StringBuilder(param0) {
  this.val = param0;
}
const _M0FPB12random__seed = () => {
  if (globalThis.crypto?.getRandomValues) {
    const array = new Uint32Array(1);
    globalThis.crypto.getRandomValues(array);
    return array[0] | 0; // Convert to signed 32
  } else {
    return Math.floor(Math.random() * 0x100000000) | 0; // Fallback to Math.random
  }
};
function _M0TPC16string10StringView(param0, param1, param2) {
  this.str = param0;
  this.start = param1;
  this.end = param2;
}
const _M0FPB19int__to__string__js = (x, radix) => {
  return x.toString(radix);
};
const _M0FPB21int64__to__string__js = (num, radix) => BigInt.asIntN(64, num).toString(radix);
function _M0TPB4IterGUiRP312moonbitstack7moonrpc6client10ClientCallEE(param0, param1) {
  this.f = param0;
  this.size_hint = param1;
}
function _M0TPB9ArrayViewGyE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function $makebytes(a, b) {
  const arr = new Uint8Array(a);
  if (b !== 0) {
    arr.fill(b);
  }
  return arr;
}
const _M0MPB7JSArray4push = (arr, val) => { arr.push(val); };
function _M0TPB3MapGsRP312moonbitstack7moonrpc6stream7HandlerE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB3MapGiRP312moonbitstack7moonrpc6server9SrvStreamE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB3MapGiRP312moonbitstack7moonrpc6client10ClientCallE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB3MapGiRPC16buffer6BufferE(param0, param1, param2, param3, param4, param5, param6) {
  this.entries = param0;
  this.size = param1;
  this.capacity = param2;
  this.capacity_mask = param3;
  this.grow_at = param4;
  this.head = param5;
  this.tail = param6;
}
function _M0TPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGiRP312moonbitstack7moonrpc6server9SrvStreamE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGiRP312moonbitstack7moonrpc6client10ClientCallE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB5EntryGiRPC16buffer6BufferE(param0, param1, param2, param3, param4, param5) {
  this.prev = param0;
  this.next = param1;
  this.psl = param2;
  this.hash = param3;
  this.key = param4;
  this.value = param5;
}
function _M0TPB8MutLocalGORPB5EntryGiRP312moonbitstack7moonrpc6client10ClientCallEE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGiE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGORPB5EntryGiRP312moonbitstack7moonrpc6server9SrvStreamEE(param0) {
  this.val = param0;
}
function _M0TPC15bytes9BytesView(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
const $bytes_literal$0 = new Uint8Array();
const _M0MPB7JSArray11set__length = (arr, len) => { arr.length = len; };
const _M0MPB7JSArray6splice = (arr, idx, cnt) => arr.splice(idx, cnt);
const _M0MPB7JSArray7splice1 = (arr, idx, cnt, val) => arr.splice(idx, cnt, val);
function _M0TPB9ArrayViewGsE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
const _M0FPC28encoding4utf816encode__utf8__js = (() => {
   const encoder = new TextEncoder();
   return function(src, start, len, bom) {
     const end = start + len;
     const encoded = encoder.encode(src.slice(start, end));
     if (!bom) {
       return encoded;
     }
     const result = new Uint8Array(encoded.length + 3);
     result[0] = 0xEF;
     result[1] = 0xBB;
     result[2] = 0xBF;
     result.set(encoded, 3);
     return result;
   };
 })();
const _M0FPC28encoding4utf816decode__utf8__js = ((preserveBOMDecoder, dropBOMDecoder) => function(bytes, start, len, preserveBOM) {
   try {
     const end = start + len;
     const slice = bytes.subarray(start, end);
     const decoder = preserveBOM ? preserveBOMDecoder : dropBOMDecoder;
     return [decoder.decode(slice)];
   } catch (_) {
     return [];
   }
 })(
   new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }),
   new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }),
 );
const _M0FPC28encoding4utf823decode__utf8__lossy__js = ((preserveBOMDecoder, dropBOMDecoder) => function(bytes, start, len, preserveBOM) {
   const end = start + len;
   const slice = bytes.subarray(start, end);
   const decoder = preserveBOM ? preserveBOMDecoder : dropBOMDecoder;
   return decoder.decode(slice);
 })(
   new TextDecoder("utf-8", { ignoreBOM: true }),
   new TextDecoder("utf-8", { ignoreBOM: false }),
 );
function _M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE2Ok.prototype.$tag = 1;
function _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated.prototype.$tag = 29;
function _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader.prototype.$tag = 28;
function _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode.prototype.$tag = 27;
function _M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eDistance(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eDistance.prototype.$tag = 26;
function _M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eChecksum(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eChecksum.prototype.$tag = 25;
function _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eLength(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eLength.prototype.$tag = 24;
function _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eTooBig(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eTooBig.prototype.$tag = 23;
function _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(param0, param1, param2) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
}
_M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault.prototype.$tag = 22;
function _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault.prototype.$tag = 21;
function _M0DTPC15error5Error41moonbitstack_2fmoonbase_2eMalformed_2eBad(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error41moonbitstack_2fmoonbase_2eMalformed_2eBad.prototype.$tag = 20;
function _M0DTPC15error5Error47moonbitstack_2fmoonbase_2eMalformed_2eTruncated(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error47moonbitstack_2fmoonbase_2eMalformed_2eTruncated.prototype.$tag = 19;
function _M0DTPC15error5Error45moonbitstack_2fmoonbase_2eMalformed_2ePadding(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error45moonbitstack_2fmoonbase_2eMalformed_2ePadding.prototype.$tag = 18;
function _M0DTPC15error5Error46moonbitstack_2fmoonbase_2eMalformed_2eChecksum(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error46moonbitstack_2fmoonbase_2eMalformed_2eChecksum.prototype.$tag = 17;
function _M0DTPC15error5Error60moonbitlang_2fcore_2fencoding_2futf8_2eMalformed_2eMalformed(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error60moonbitlang_2fcore_2fencoding_2futf8_2eMalformed_2eMalformed.prototype.$tag = 16;
function _M0DTPC15error5Error57moonbitstack_2fmoonrpc_2fwire_2eStatusError_2eStatusError(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error57moonbitstack_2fmoonrpc_2fwire_2eStatusError_2eStatusError.prototype.$tag = 15;
function _M0DTPC15error5Error53moonbitstack_2fmoonvar_2fleb128_2eRefused_2eTruncated(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error53moonbitstack_2fmoonvar_2fleb128_2eRefused_2eTruncated.prototype.$tag = 14;
function _M0DTPC15error5Error52moonbitstack_2fmoonvar_2fleb128_2eRefused_2eExceeded(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error52moonbitstack_2fmoonvar_2fleb128_2eRefused_2eExceeded.prototype.$tag = 13;
function _M0DTPC15error5Error65moonbitstack_2fmoonrpc_2fstream_2eStreamError_2eInvalidTransition(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error65moonbitstack_2fmoonrpc_2fstream_2eStreamError_2eInvalidTransition.prototype.$tag = 12;
function _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed.prototype.$tag = 11;
function _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eIndex(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eIndex.prototype.$tag = 10;
function _M0DTPC15error5Error52moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eExceeded(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error52moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eExceeded.prototype.$tag = 9;
function _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eEos() {}
_M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eEos.prototype.$tag = 8;
const _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eEos__ = new _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eEos();
function _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2ePadding(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2ePadding.prototype.$tag = 7;
function _M0DTPC15error5Error55moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eMalformed(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error55moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eMalformed.prototype.$tag = 6;
function _M0DTPC15error5Error53moonbitstack_2fmoonvar_2fprefix_2eRefused_2eTruncated(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error53moonbitstack_2fmoonvar_2fprefix_2eRefused_2eTruncated.prototype.$tag = 5;
function _M0DTPC15error5Error52moonbitstack_2fmoonvar_2fprefix_2eRefused_2eExceeded(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTPC15error5Error52moonbitstack_2fmoonvar_2fprefix_2eRefused_2eExceeded.prototype.$tag = 4;
function _M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated() {}
_M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated.prototype.$tag = 3;
const _M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated__ = new _M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated();
function _M0DTPC15error5Error54moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadWireType(param0) {
  this._0 = param0;
}
_M0DTPC15error5Error54moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadWireType.prototype.$tag = 2;
function _M0DTPC15error5Error51moonbitstack_2fmoonrpc_2fproto_2ePbError_2eOverflow() {}
_M0DTPC15error5Error51moonbitstack_2fmoonrpc_2fproto_2ePbError_2eOverflow.prototype.$tag = 1;
const _M0DTPC15error5Error51moonbitstack_2fmoonrpc_2fproto_2ePbError_2eOverflow__ = new _M0DTPC15error5Error51moonbitstack_2fmoonrpc_2fproto_2ePbError_2eOverflow();
function _M0DTPC15error5Error50moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadUtf8() {}
_M0DTPC15error5Error50moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadUtf8.prototype.$tag = 0;
const _M0DTPC15error5Error50moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadUtf8__ = new _M0DTPC15error5Error50moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadUtf8();
function _M0TPC16buffer6Buffer(param0, param1) {
  this.data = param0;
  this.len = param1;
}
function _M0TP312moonbitstack8moonhttp7huffman4Node(param0, param1, param2) {
  this.zero = param0;
  this.one = param1;
  this.sym = param2;
}
function _M0TPB8MutLocalGmE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGbE(param0) {
  this.val = param0;
}
function _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE2Ok.prototype.$tag = 1;
function _M0TPB8MutLocalGlE(param0) {
  this.val = param0;
}
function _M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack8moonhttp5hpack5Table(param0, param1, param2) {
  this.entries = param0;
  this.size = param1;
  this.limit = param2;
}
function _M0TP312moonbitstack8moonhttp5hpack7Decoder(param0, param1) {
  this.table = param0;
  this.limit = param1;
}
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack8moonhttp5hpack7Encoder(param0, param1) {
  this.table = param0;
  this.huffman = param1;
}
function $bytes_equal(a, b) {
    if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}
function _M0TPB8MutLocalGjE(param0) {
  this.val = param0;
}
function _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE2Ok.prototype.$tag = 1;
const $bytes_literal$1 = new Uint8Array([99,111,110,116,101,110,116,45,116,121,112,101]);
const $bytes_literal$2 = new Uint8Array([116,101]);
const $bytes_literal$3 = new Uint8Array([103,114,112,99,45,116,105,109,101,111,117,116]);
const $bytes_literal$4 = new Uint8Array([103,114,112,99,45,101,110,99,111,100,105,110,103]);
const $bytes_literal$5 = new Uint8Array([103,114,112,99,45,97,99,99,101,112,116,45,101,110,99,111,100,105,110,103]);
const $bytes_literal$6 = new Uint8Array([117,115,101,114,45,97,103,101,110,116]);
function _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonzip7deflate7Huffman(param0, param1) {
  this.counts = param0;
  this.symbols = param1;
}
function _M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonzip7deflate6Reader(param0, param1, param2, param3) {
  this.src = param0;
  this.pos = param1;
  this.acc = param2;
  this.held = param3;
}
function _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonrpc6client10ClientCall(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22, param23, param24, param25, param26, param27, param28) {
  this.id = param0;
  this.path = param1;
  this.authority = param2;
  this.metadata = param3;
  this.timeout = param4;
  this.out = param5;
  this.out_off = param6;
  this.req_ended = param7;
  this.req_headers_sent = param8;
  this.req_fin_sent = param9;
  this.send_window = param10;
  this.data = param11;
  this.data_off = param12;
  this.messages = param13;
  this.recv_window = param14;
  this.status = param15;
  this.grpc_status = param16;
  this.grpc_message = param17;
  this.resp_encoding = param18;
  this.resp_headers = param19;
  this.resp_trailers = param20;
  this.headers_seen = param21;
  this.header_block = param22;
  this.in_headers = param23;
  this.pending_end_stream = param24;
  this.decode_failed = param25;
  this.unprocessed = param26;
  this.committed = param27;
  this.done = param28;
}
function _M0DTP312moonbitstack8moonhttp5http25Frame4Data(param0, param1, param2, param3) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
  this._3 = param3;
}
_M0DTP312moonbitstack8moonhttp5http25Frame4Data.prototype.$tag = 0;
function _M0DTP312moonbitstack8moonhttp5http25Frame7Headers(param0, param1, param2, param3, param4, param5) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
  this._3 = param3;
  this._4 = param4;
  this._5 = param5;
}
_M0DTP312moonbitstack8moonhttp5http25Frame7Headers.prototype.$tag = 1;
function _M0DTP312moonbitstack8moonhttp5http25Frame8Priority(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP312moonbitstack8moonhttp5http25Frame8Priority.prototype.$tag = 2;
function _M0DTP312moonbitstack8moonhttp5http25Frame9RstStream(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP312moonbitstack8moonhttp5http25Frame9RstStream.prototype.$tag = 3;
function _M0DTP312moonbitstack8moonhttp5http25Frame8Settings(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP312moonbitstack8moonhttp5http25Frame8Settings.prototype.$tag = 4;
function _M0DTP312moonbitstack8moonhttp5http25Frame11PushPromise(param0, param1, param2, param3, param4) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
  this._3 = param3;
  this._4 = param4;
}
_M0DTP312moonbitstack8moonhttp5http25Frame11PushPromise.prototype.$tag = 5;
function _M0DTP312moonbitstack8moonhttp5http25Frame4Ping(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP312moonbitstack8moonhttp5http25Frame4Ping.prototype.$tag = 6;
function _M0DTP312moonbitstack8moonhttp5http25Frame6GoAway(param0, param1, param2) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
}
_M0DTP312moonbitstack8moonhttp5http25Frame6GoAway.prototype.$tag = 7;
function _M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate(param0, param1) {
  this._0 = param0;
  this._1 = param1;
}
_M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate.prototype.$tag = 8;
function _M0DTP312moonbitstack8moonhttp5http25Frame12Continuation(param0, param1, param2) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
}
_M0DTP312moonbitstack8moonhttp5http25Frame12Continuation.prototype.$tag = 9;
function _M0DTP312moonbitstack8moonhttp5http25Frame7Unknown(param0, param1, param2, param3) {
  this._0 = param0;
  this._1 = param1;
  this._2 = param2;
  this._3 = param3;
}
_M0DTP312moonbitstack8moonhttp5http25Frame7Unknown.prototype.$tag = 10;
function _M0TP312moonbitstack7moonrpc6client8H2Client(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10) {
  this.encoder = param0;
  this.decoder = param1;
  this.calls = param2;
  this.next_id = param3;
  this.conn_send_window = param4;
  this.conn_recv_window = param5;
  this.remote_initial_window = param6;
  this.remote_max_frame = param7;
  this.goaway_received = param8;
  this.goaway_last_stream_id = param9;
  this.orphan_blocks = param10;
}
function _M0TPB9ArrayViewGUiRP312moonbitstack7moonrpc6client10ClientCallEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB9ArrayViewGUiRPC16buffer6BufferEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
const $bytes_literal$7 = new Uint8Array([109]);
const $bytes_literal$8 = new Uint8Array([83]);
const $bytes_literal$9 = new Uint8Array([58,109,101,116,104,111,100]);
const $bytes_literal$10 = new Uint8Array([80,79,83,84]);
const $bytes_literal$11 = new Uint8Array([58,115,99,104,101,109,101]);
const $bytes_literal$12 = new Uint8Array([104,116,116,112]);
const $bytes_literal$13 = new Uint8Array([58,112,97,116,104]);
const $bytes_literal$14 = new Uint8Array([58,97,117,116,104,111,114,105,116,121]);
const $bytes_literal$15 = new Uint8Array([116,114,97,105,108,101,114,115]);
const $bytes_literal$16 = new Uint8Array([97,112,112,108,105,99,97,116,105,111,110,47,103,114,112,99]);
function _M0TPB9ArrayViewGRP312moonbitstack8moonhttp6header6HeaderE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
const $bytes_literal$17 = new Uint8Array([103,122,105,112]);
const $bytes_literal$18 = new Uint8Array([58,115,116,97,116,117,115]);
const $bytes_literal$19 = new Uint8Array([103,114,112,99,45,115,116,97,116,117,115]);
const $bytes_literal$20 = new Uint8Array([103,114,112,99,45,109,101,115,115,97,103,101]);
function _M0DTPC16result6ResultGuRPC15error5ErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRPC15error5ErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRPC15error5ErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRPC15error5ErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonrpc6client9CallReply(param0, param1, param2, param3, param4, param5, param6, param7) {
  this.status = param0;
  this.grpc_status = param1;
  this.grpc_message = param2;
  this.headers = param3;
  this.messages = param4;
  this.trailers = param5;
  this.committed = param6;
  this.unprocessed = param7;
}
function _M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonrpc5proto8PbWriter(param0) {
  this.buf = param0;
}
function _M0TP312moonbitstack7moonrpc5proto8PbReader(param0, param1) {
  this.data = param0;
  this.pos = param1;
}
function _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0DTPC16result6ResultGuRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGuRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGuRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonrpc6stream10RpcContext(param0, param1, param2, param3, param4, param5, param6) {
  this.path = param0;
  this.metadata = param1;
  this.deadline_millis = param2;
  this.resp_headers = param3;
  this.resp_trailers = param4;
  this.status_fail = param5;
  this.error_details = param6;
}
function _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok.prototype.$tag = 1;
function _M0TP312moonbitstack7moonrpc6server9SrvStream(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22, param23, param24, param25, param26, param27, param28, param29, param30) {
  this.id = param0;
  this.state = param1;
  this.header_block = param2;
  this.data = param3;
  this.req_off = param4;
  this.req_msgs = param5;
  this.bidi_processed = param6;
  this.headers_complete = param7;
  this.in_headers = param8;
  this.end_stream_recv = param9;
  this.path = param10;
  this.ctx = param11;
  this.deadline_at = param12;
  this.recv_window = param13;
  this.send_window = param14;
  this.out = param15;
  this.out_off = param16;
  this.started = param17;
  this.started_response = param18;
  this.response_ended = param19;
  this.finalized = param20;
  this.trailers_only = param21;
  this.http_status = param22;
  this.status_code = param23;
  this.status_message = param24;
  this.req_encoding = param25;
  this.compressed_unsupported = param26;
  this.oversize = param27;
  this.headers_sent = param28;
  this.trailers_sent = param29;
  this.bidi = param30;
}
function _M0TP312moonbitstack7moonrpc6server8H2Server(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16) {
  this.handlers = param0;
  this.encoder = param1;
  this.decoder = param2;
  this.streams = param3;
  this.unary_interceptors = param4;
  this.stream_interceptors = param5;
  this.conn_recv_window = param6;
  this.conn_send_window = param7;
  this.remote_initial_window = param8;
  this.remote_max_frame = param9;
  this.max_streams = param10;
  this.clock = param11;
  this.continuing = param12;
  this.goaway_received = param13;
  this.last_client_stream = param14;
  this.closing = param15;
  this.drained = param16;
}
function _M0TPB9ArrayViewGUsRP312moonbitstack7moonrpc6stream7HandlerEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0TPB9ArrayViewGUiRP312moonbitstack7moonrpc6server9SrvStreamEE(param0, param1, param2) {
  this.buf = param0;
  this.start = param1;
  this.end = param2;
}
function _M0DTP312moonbitstack7moonrpc6stream7Handler5Unary(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream7Handler5Unary.prototype.$tag = 0;
function _M0DTP312moonbitstack7moonrpc6stream7Handler15ServerStreaming(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream7Handler15ServerStreaming.prototype.$tag = 1;
function _M0DTP312moonbitstack7moonrpc6stream7Handler15ClientStreaming(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream7Handler15ClientStreaming.prototype.$tag = 2;
function _M0DTP312moonbitstack7moonrpc6stream7Handler4Bidi(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream7Handler4Bidi.prototype.$tag = 3;
function _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE2Ok.prototype.$tag = 1;
const $bytes_literal$21 = new Uint8Array([105,100,101,110,116,105,116,121,44,103,122,105,112]);
const $bytes_literal$22 = new Uint8Array([103,114,112,99,45,115,116,97,116,117,115,45,100,101,116,97,105,108,115,45,98,105,110]);
function _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers.prototype.$tag = 0;
function _M0DTP312moonbitstack7moonrpc6stream11StreamEvent4Data(param0) {
  this._0 = param0;
}
_M0DTP312moonbitstack7moonrpc6stream11StreamEvent4Data.prototype.$tag = 1;
function _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Reserve() {}
_M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Reserve.prototype.$tag = 2;
function _M0DTP312moonbitstack7moonrpc6stream11StreamEvent9RstStream() {}
_M0DTP312moonbitstack7moonrpc6stream11StreamEvent9RstStream.prototype.$tag = 3;
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok.prototype.$tag = 1;
const $bytes_literal$23 = new Uint8Array([50,48,48]);
const $bytes_literal$24 = new Uint8Array([105,100,101,110,116,105,116,121]);
function _M0TPB8MutLocalGWRP312moonbitstack7moonrpc6stream10RpcContextzERPB5ArrayGzEE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGWRP312moonbitstack7moonrpc6stream10RpcContextzEzE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGRPB13StringBuilderE(param0) {
  this.val = param0;
}
function _M0TPB8MutLocalGsE(param0) {
  this.val = param0;
}
function _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc5proto7PbErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc5proto7PbErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc5proto7PbErrorE2Ok.prototype.$tag = 1;
function _M0TP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5Greet(param0) {
  this.text = param0;
}
function _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc4wire11StatusErrorE3Err(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc4wire11StatusErrorE3Err.prototype.$tag = 0;
function _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc4wire11StatusErrorE2Ok(param0) {
  this._0 = param0;
}
_M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc4wire11StatusErrorE2Ok.prototype.$tag = 1;
const $bytes_literal$25 = new Uint8Array([49]);
const $bytes_literal$26 = new Uint8Array([50]);
const $bytes_literal$27 = new Uint8Array([51]);
const $bytes_literal$28 = new Uint8Array([103,111,116]);
function _M0TP312moonbitstack7moonrpc6stream11BidiHandler(param0, param1) {
  this.on_message = param0;
  this.on_end = param1;
}
const $bytes_literal$29 = new Uint8Array([33]);
function _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None() {}
_M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None.prototype.$tag = 0;
const _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None__ = new _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None();
function _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4Some(param0) {
  this._0 = param0;
}
_M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4Some.prototype.$tag = 1;
const $bytes_literal$30 = new Uint8Array([103,111]);
const $bytes_literal$31 = new Uint8Array([97]);
const $bytes_literal$32 = new Uint8Array([98]);
const $bytes_literal$33 = new Uint8Array([104,105]);
const $bytes_literal$34 = new Uint8Array([121,111]);
const _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo15js__set__global = (name, f) => { globalThis[name] = f; };
const _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger = { method_0: _M0IPB13StringBuilderPB6Logger13write__string, method_1: _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE, method_2: _M0IPB13StringBuilderPB6Logger11write__view, method_3: _M0IPB13StringBuilderPB6Logger11write__char, method_4: _M0IP016_24default__implPB6Logger28write__string__interpolationGRPB13StringBuilderE, method_5: _M0IP016_24default__implPB6Logger5writeGRPB13StringBuilderE };
function _M0FP15Error10to__string(_e) {
  switch (_e.$tag) {
    case 10: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp5hpack7RefusedE(_e);
    }
    case 25: {
      return "moonbitstack/moonzip.Broken.Checksum";
    }
    case 16: {
      return "moonbitlang/core/encoding/utf8.Malformed.Malformed";
    }
    case 9: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp5hpack7RefusedE(_e);
    }
    case 6: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp7huffman7RefusedE(_e);
    }
    case 15: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc4wire11StatusErrorE(_e);
    }
    case 1: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc5proto7PbErrorE(_e);
    }
    case 27: {
      return "moonbitstack/moonzip.Broken.Code";
    }
    case 8: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp7huffman7RefusedE(_e);
    }
    case 24: {
      return "moonbitstack/moonzip.Broken.Length";
    }
    case 12: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc6stream11StreamErrorE(_e);
    }
    case 3: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc5proto7PbErrorE(_e);
    }
    case 26: {
      return "moonbitstack/moonzip.Broken.Distance";
    }
    case 22: {
      return "moonbitstack/moonrpc/internal/h2.Fault.StreamFault";
    }
    case 5: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6prefix7RefusedE(_e);
    }
    case 7: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp7huffman7RefusedE(_e);
    }
    case 4: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6prefix7RefusedE(_e);
    }
    case 19: {
      return "moonbitstack/moonbase.Malformed.Truncated";
    }
    case 13: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6leb1287RefusedE(_e);
    }
    case 0: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc5proto7PbErrorE(_e);
    }
    case 23: {
      return "moonbitstack/moonzip.Broken.TooBig";
    }
    case 21: {
      return "moonbitstack/moonrpc/internal/h2.Fault.ConnFault";
    }
    case 17: {
      return "moonbitstack/moonbase.Malformed.Checksum";
    }
    case 11: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp5hpack7RefusedE(_e);
    }
    case 18: {
      return "moonbitstack/moonbase.Malformed.Padding";
    }
    case 14: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6leb1287RefusedE(_e);
    }
    case 29: {
      return "moonbitstack/moonzip.Broken.Truncated";
    }
    case 20: {
      return "moonbitstack/moonbase.Malformed.Bad";
    }
    case 2: {
      return _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc5proto7PbErrorE(_e);
    }
    default: {
      return "moonbitstack/moonzip.Broken.Header";
    }
  }
}
const _M0MPB4Iter4nextN6constrS111GUiRP312moonbitstack7moonrpc6client10ClientCallEE = 0;
const _M0MPB4Iter4nextN6constrS112GUiRP312moonbitstack7moonrpc6client10ClientCallEE = 0;
const _M0MPB4Iter3newN6constrS139GUiRP312moonbitstack7moonrpc6client10ClientCallEE = 0;
const _M0FP312moonbitstack8moonhttp7huffman5table = [{ _0: 8184, _1: 13 }, { _0: 8388568, _1: 23 }, { _0: 268435426, _1: 28 }, { _0: 268435427, _1: 28 }, { _0: 268435428, _1: 28 }, { _0: 268435429, _1: 28 }, { _0: 268435430, _1: 28 }, { _0: 268435431, _1: 28 }, { _0: 268435432, _1: 28 }, { _0: 16777194, _1: 24 }, { _0: 1073741820, _1: 30 }, { _0: 268435433, _1: 28 }, { _0: 268435434, _1: 28 }, { _0: 1073741821, _1: 30 }, { _0: 268435435, _1: 28 }, { _0: 268435436, _1: 28 }, { _0: 268435437, _1: 28 }, { _0: 268435438, _1: 28 }, { _0: 268435439, _1: 28 }, { _0: 268435440, _1: 28 }, { _0: 268435441, _1: 28 }, { _0: 268435442, _1: 28 }, { _0: 1073741822, _1: 30 }, { _0: 268435443, _1: 28 }, { _0: 268435444, _1: 28 }, { _0: 268435445, _1: 28 }, { _0: 268435446, _1: 28 }, { _0: 268435447, _1: 28 }, { _0: 268435448, _1: 28 }, { _0: 268435449, _1: 28 }, { _0: 268435450, _1: 28 }, { _0: 268435451, _1: 28 }, { _0: 20, _1: 6 }, { _0: 1016, _1: 10 }, { _0: 1017, _1: 10 }, { _0: 4090, _1: 12 }, { _0: 8185, _1: 13 }, { _0: 21, _1: 6 }, { _0: 248, _1: 8 }, { _0: 2042, _1: 11 }, { _0: 1018, _1: 10 }, { _0: 1019, _1: 10 }, { _0: 249, _1: 8 }, { _0: 2043, _1: 11 }, { _0: 250, _1: 8 }, { _0: 22, _1: 6 }, { _0: 23, _1: 6 }, { _0: 24, _1: 6 }, { _0: 0, _1: 5 }, { _0: 1, _1: 5 }, { _0: 2, _1: 5 }, { _0: 25, _1: 6 }, { _0: 26, _1: 6 }, { _0: 27, _1: 6 }, { _0: 28, _1: 6 }, { _0: 29, _1: 6 }, { _0: 30, _1: 6 }, { _0: 31, _1: 6 }, { _0: 92, _1: 7 }, { _0: 251, _1: 8 }, { _0: 32764, _1: 15 }, { _0: 32, _1: 6 }, { _0: 4091, _1: 12 }, { _0: 1020, _1: 10 }, { _0: 8186, _1: 13 }, { _0: 33, _1: 6 }, { _0: 93, _1: 7 }, { _0: 94, _1: 7 }, { _0: 95, _1: 7 }, { _0: 96, _1: 7 }, { _0: 97, _1: 7 }, { _0: 98, _1: 7 }, { _0: 99, _1: 7 }, { _0: 100, _1: 7 }, { _0: 101, _1: 7 }, { _0: 102, _1: 7 }, { _0: 103, _1: 7 }, { _0: 104, _1: 7 }, { _0: 105, _1: 7 }, { _0: 106, _1: 7 }, { _0: 107, _1: 7 }, { _0: 108, _1: 7 }, { _0: 109, _1: 7 }, { _0: 110, _1: 7 }, { _0: 111, _1: 7 }, { _0: 112, _1: 7 }, { _0: 113, _1: 7 }, { _0: 114, _1: 7 }, { _0: 252, _1: 8 }, { _0: 115, _1: 7 }, { _0: 253, _1: 8 }, { _0: 8187, _1: 13 }, { _0: 524272, _1: 19 }, { _0: 8188, _1: 13 }, { _0: 16380, _1: 14 }, { _0: 34, _1: 6 }, { _0: 32765, _1: 15 }, { _0: 3, _1: 5 }, { _0: 35, _1: 6 }, { _0: 4, _1: 5 }, { _0: 36, _1: 6 }, { _0: 5, _1: 5 }, { _0: 37, _1: 6 }, { _0: 38, _1: 6 }, { _0: 39, _1: 6 }, { _0: 6, _1: 5 }, { _0: 116, _1: 7 }, { _0: 117, _1: 7 }, { _0: 40, _1: 6 }, { _0: 41, _1: 6 }, { _0: 42, _1: 6 }, { _0: 7, _1: 5 }, { _0: 43, _1: 6 }, { _0: 118, _1: 7 }, { _0: 44, _1: 6 }, { _0: 8, _1: 5 }, { _0: 9, _1: 5 }, { _0: 45, _1: 6 }, { _0: 119, _1: 7 }, { _0: 120, _1: 7 }, { _0: 121, _1: 7 }, { _0: 122, _1: 7 }, { _0: 123, _1: 7 }, { _0: 32766, _1: 15 }, { _0: 2044, _1: 11 }, { _0: 16381, _1: 14 }, { _0: 8189, _1: 13 }, { _0: 268435452, _1: 28 }, { _0: 1048550, _1: 20 }, { _0: 4194258, _1: 22 }, { _0: 1048551, _1: 20 }, { _0: 1048552, _1: 20 }, { _0: 4194259, _1: 22 }, { _0: 4194260, _1: 22 }, { _0: 4194261, _1: 22 }, { _0: 8388569, _1: 23 }, { _0: 4194262, _1: 22 }, { _0: 8388570, _1: 23 }, { _0: 8388571, _1: 23 }, { _0: 8388572, _1: 23 }, { _0: 8388573, _1: 23 }, { _0: 8388574, _1: 23 }, { _0: 16777195, _1: 24 }, { _0: 8388575, _1: 23 }, { _0: 16777196, _1: 24 }, { _0: 16777197, _1: 24 }, { _0: 4194263, _1: 22 }, { _0: 8388576, _1: 23 }, { _0: 16777198, _1: 24 }, { _0: 8388577, _1: 23 }, { _0: 8388578, _1: 23 }, { _0: 8388579, _1: 23 }, { _0: 8388580, _1: 23 }, { _0: 2097116, _1: 21 }, { _0: 4194264, _1: 22 }, { _0: 8388581, _1: 23 }, { _0: 4194265, _1: 22 }, { _0: 8388582, _1: 23 }, { _0: 8388583, _1: 23 }, { _0: 16777199, _1: 24 }, { _0: 4194266, _1: 22 }, { _0: 2097117, _1: 21 }, { _0: 1048553, _1: 20 }, { _0: 4194267, _1: 22 }, { _0: 4194268, _1: 22 }, { _0: 8388584, _1: 23 }, { _0: 8388585, _1: 23 }, { _0: 2097118, _1: 21 }, { _0: 8388586, _1: 23 }, { _0: 4194269, _1: 22 }, { _0: 4194270, _1: 22 }, { _0: 16777200, _1: 24 }, { _0: 2097119, _1: 21 }, { _0: 4194271, _1: 22 }, { _0: 8388587, _1: 23 }, { _0: 8388588, _1: 23 }, { _0: 2097120, _1: 21 }, { _0: 2097121, _1: 21 }, { _0: 4194272, _1: 22 }, { _0: 2097122, _1: 21 }, { _0: 8388589, _1: 23 }, { _0: 4194273, _1: 22 }, { _0: 8388590, _1: 23 }, { _0: 8388591, _1: 23 }, { _0: 1048554, _1: 20 }, { _0: 4194274, _1: 22 }, { _0: 4194275, _1: 22 }, { _0: 4194276, _1: 22 }, { _0: 8388592, _1: 23 }, { _0: 4194277, _1: 22 }, { _0: 4194278, _1: 22 }, { _0: 8388593, _1: 23 }, { _0: 67108832, _1: 26 }, { _0: 67108833, _1: 26 }, { _0: 1048555, _1: 20 }, { _0: 524273, _1: 19 }, { _0: 4194279, _1: 22 }, { _0: 8388594, _1: 23 }, { _0: 4194280, _1: 22 }, { _0: 33554412, _1: 25 }, { _0: 67108834, _1: 26 }, { _0: 67108835, _1: 26 }, { _0: 67108836, _1: 26 }, { _0: 134217694, _1: 27 }, { _0: 134217695, _1: 27 }, { _0: 67108837, _1: 26 }, { _0: 16777201, _1: 24 }, { _0: 33554413, _1: 25 }, { _0: 524274, _1: 19 }, { _0: 2097123, _1: 21 }, { _0: 67108838, _1: 26 }, { _0: 134217696, _1: 27 }, { _0: 134217697, _1: 27 }, { _0: 67108839, _1: 26 }, { _0: 134217698, _1: 27 }, { _0: 16777202, _1: 24 }, { _0: 2097124, _1: 21 }, { _0: 2097125, _1: 21 }, { _0: 67108840, _1: 26 }, { _0: 67108841, _1: 26 }, { _0: 268435453, _1: 28 }, { _0: 134217699, _1: 27 }, { _0: 134217700, _1: 27 }, { _0: 134217701, _1: 27 }, { _0: 1048556, _1: 20 }, { _0: 16777203, _1: 24 }, { _0: 1048557, _1: 20 }, { _0: 2097126, _1: 21 }, { _0: 4194282, _1: 22 }, { _0: 2097127, _1: 21 }, { _0: 2097128, _1: 21 }, { _0: 8388595, _1: 23 }, { _0: 4194283, _1: 22 }, { _0: 4194281, _1: 22 }, { _0: 33554414, _1: 25 }, { _0: 33554415, _1: 25 }, { _0: 16777204, _1: 24 }, { _0: 16777205, _1: 24 }, { _0: 67108842, _1: 26 }, { _0: 8388596, _1: 23 }, { _0: 67108843, _1: 26 }, { _0: 134217702, _1: 27 }, { _0: 67108844, _1: 26 }, { _0: 67108845, _1: 26 }, { _0: 134217703, _1: 27 }, { _0: 134217704, _1: 27 }, { _0: 134217705, _1: 27 }, { _0: 134217706, _1: 27 }, { _0: 134217707, _1: 27 }, { _0: 268435454, _1: 28 }, { _0: 134217708, _1: 27 }, { _0: 134217709, _1: 27 }, { _0: 134217710, _1: 27 }, { _0: 134217711, _1: 27 }, { _0: 134217712, _1: 27 }, { _0: 67108846, _1: 26 }, { _0: 1073741823, _1: 30 }];
const _M0FP312moonbitstack8moonhttp7huffman3eos = 256;
const _M0FP312moonbitstack7moonvar6prefix5limit = 2147483647n;
const _M0FP312moonbitstack8moonhttp5hpack5limit = 4096;
const _M0FP312moonbitstack8moonhttp5hpack12ascii__table = [{ _0: ":authority", _1: "" }, { _0: ":method", _1: "GET" }, { _0: ":method", _1: "POST" }, { _0: ":path", _1: "/" }, { _0: ":path", _1: "/index.html" }, { _0: ":scheme", _1: "http" }, { _0: ":scheme", _1: "https" }, { _0: ":status", _1: "200" }, { _0: ":status", _1: "204" }, { _0: ":status", _1: "206" }, { _0: ":status", _1: "304" }, { _0: ":status", _1: "400" }, { _0: ":status", _1: "404" }, { _0: ":status", _1: "500" }, { _0: "accept-charset", _1: "" }, { _0: "accept-encoding", _1: "gzip, deflate" }, { _0: "accept-language", _1: "" }, { _0: "accept-ranges", _1: "" }, { _0: "accept", _1: "" }, { _0: "access-control-allow-origin", _1: "" }, { _0: "age", _1: "" }, { _0: "allow", _1: "" }, { _0: "authorization", _1: "" }, { _0: "cache-control", _1: "" }, { _0: "content-disposition", _1: "" }, { _0: "content-encoding", _1: "" }, { _0: "content-language", _1: "" }, { _0: "content-length", _1: "" }, { _0: "content-location", _1: "" }, { _0: "content-range", _1: "" }, { _0: "content-type", _1: "" }, { _0: "cookie", _1: "" }, { _0: "date", _1: "" }, { _0: "etag", _1: "" }, { _0: "expect", _1: "" }, { _0: "expires", _1: "" }, { _0: "from", _1: "" }, { _0: "host", _1: "" }, { _0: "if-match", _1: "" }, { _0: "if-modified-since", _1: "" }, { _0: "if-none-match", _1: "" }, { _0: "if-range", _1: "" }, { _0: "if-unmodified-since", _1: "" }, { _0: "last-modified", _1: "" }, { _0: "link", _1: "" }, { _0: "location", _1: "" }, { _0: "max-forwards", _1: "" }, { _0: "proxy-authenticate", _1: "" }, { _0: "proxy-authorization", _1: "" }, { _0: "range", _1: "" }, { _0: "referer", _1: "" }, { _0: "refresh", _1: "" }, { _0: "retry-after", _1: "" }, { _0: "server", _1: "" }, { _0: "set-cookie", _1: "" }, { _0: "strict-transport-security", _1: "" }, { _0: "transfer-encoding", _1: "" }, { _0: "user-agent", _1: "" }, { _0: "vary", _1: "" }, { _0: "via", _1: "" }, { _0: "www-authenticate", _1: "" }];
const _M0FP312moonbitstack7moonvar5fixed5order = 0;
const _M0FP312moonbitstack8moonhttp5http222settings__enable__push = 2;
const _M0FP312moonbitstack8moonhttp5http229settings__header__table__size = 1;
const _M0FP312moonbitstack8moonhttp5http231settings__initial__window__size = 4;
const _M0FP312moonbitstack8moonhttp5http234settings__max__concurrent__streams = 3;
const _M0FP312moonbitstack8moonhttp5http226settings__max__frame__size = 5;
const _M0FP312moonbitstack8moonhttp5http227error__flow__control__error = 3;
const _M0FP312moonbitstack8moonhttp5http222error__protocol__error = 1;
const _M0FP312moonbitstack8moonhttp5http29flag__ack = 1;
const _M0FP312moonbitstack8moonhttp5http218flag__end__headers = 4;
const _M0FP312moonbitstack8moonhttp5http217flag__end__stream = 1;
const _M0FP312moonbitstack8moonhttp5http212flag__padded = 8;
const _M0FP312moonbitstack8moonhttp5http214flag__priority = 32;
const _M0FP312moonbitstack8moonhttp5http219frame__continuation = 9;
const _M0FP312moonbitstack8moonhttp5http211frame__data = 0;
const _M0FP312moonbitstack8moonhttp5http213frame__goaway = 7;
const _M0FP312moonbitstack8moonhttp5http214frame__headers = 1;
const _M0FP312moonbitstack8moonhttp5http211frame__ping = 6;
const _M0FP312moonbitstack8moonhttp5http215frame__priority = 2;
const _M0FP312moonbitstack8moonhttp5http220frame__push__promise = 5;
const _M0FP312moonbitstack8moonhttp5http218frame__rst__stream = 3;
const _M0FP312moonbitstack8moonhttp5http215frame__settings = 4;
const _M0FP312moonbitstack8moonhttp5http221frame__window__update = 8;
const _M0FP312moonbitstack8moonhttp5http216error__no__error = 0;
const _M0FP312moonbitstack8moonhttp5http225error__frame__size__error = 6;
const _M0FP312moonbitstack8moonhttp5http226error__enhance__your__calm = 11;
const _M0FP312moonbitstack8moonhttp5http225error__compression__error = 9;
const _M0FP312moonbitstack8moonhttp5http221error__stream__closed = 5;
const _M0FP312moonbitstack8moonhttp5http222error__refused__stream = 7;
const _M0FP312moonbitstack8moonhttp5http213error__cancel = 8;
const _M0FP312moonbitstack8moonhttp5http222error__internal__error = 2;
const _M0FP312moonbitstack8moonhttp5http227error__inadequate__security = 12;
const _M0FP312moonbitstack8moonbase6base647letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
const _M0FP312moonbitstack7moonrpc4wire18max__message__size = 4194304;
const _M0FP312moonbitstack7moonrpc4wire23max__header__list__size = 131072;
const _M0FP312moonbitstack7moonrpc4wire21default__window__size = 65535;
const _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size = 16384;
const _M0FP212moonbitstack7moonurl4kind = 0;
const _M0FP312moonbitstack7moonzip7deflate10dist__base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577];
const _M0FP312moonbitstack7moonzip7deflate11dist__extra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
const _M0FP312moonbitstack7moonzip7deflate12length__base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const _M0FP312moonbitstack7moonzip7deflate13length__extra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
const _M0FP312moonbitstack7moonzip7deflate13length__order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];
const _M0FP312moonbitstack7moonvar6leb1285limit = 10;
const _M0FP312moonbitstack7moonrpc6server21default__max__streams = 100;
const _M0FP312moonbitstack7moonrpc6server10grpc__safe = " !\"#$&'()*+,/:;<=>?@[\\]^`{|}";
const _M0FPB4seed = _M0FPB12random__seed();
const _M0FP312moonbitstack8moonbase6base649url__text = `${_M0FP312moonbitstack8moonbase6base647letters}-_`;
const _M0FP312moonbitstack8moonbase6base6411url__digits = _M0MPC16string6String9to__array(_M0FP312moonbitstack8moonbase6base649url__text);
const _M0FP312moonbitstack8moonbase6base649std__text = `${_M0FP312moonbitstack8moonbase6base647letters}+/`;
const _M0FP312moonbitstack8moonbase6base6411std__digits = _M0MPC16string6String9to__array(_M0FP312moonbitstack8moonbase6base649std__text);
const out = [];
const _bind = _M0FP312moonbitstack8moonhttp5hpack12ascii__table.length;
let _tmp = 0;
while (true) {
  const _ = _tmp;
  if (_ < _bind) {
    const e = _M0FP312moonbitstack8moonhttp5hpack12ascii__table[_];
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out, new _M0TP312moonbitstack8moonhttp6header6Header(_M0FP312moonbitstack8moonhttp5hpack6octets(e._0), _M0FP312moonbitstack8moonhttp5hpack6octets(e._1)));
    _tmp = _ + 1 | 0;
    continue;
  } else {
    break;
  }
}
const _M0FP312moonbitstack8moonhttp5hpack13static__table = out;
const _M0FP312moonbitstack8moonhttp7huffman4trie = _M0FP312moonbitstack8moonhttp7huffman5build();
const _M0FP312moonbitstack8moonbase6base6411url__lookup = _M0FP212moonbitstack8moonbase10lookup__of(_M0FP312moonbitstack8moonbase6base649url__text);
const _M0FP312moonbitstack8moonbase6base6411std__lookup = _M0FP212moonbitstack8moonbase10lookup__of(_M0FP312moonbitstack8moonbase6base649std__text);
const _M0FP312moonbitstack7moonzip7deflate11fixed__dist = _M0MP312moonbitstack7moonzip7deflate7Huffman2of($make_array_len_and_init(30, 5), 30);
const lengths = $make_array_len_and_init(288, 8);
const _bind$2 = 144;
const _bind$3 = 256;
let _tmp$2 = _bind$2;
while (true) {
  const i = _tmp$2;
  if (i < _bind$3) {
    if (i >>> 0 < lengths.length) {
      lengths[i] = 9;
    } else {
      $oob();
    }
    _tmp$2 = i + 1 | 0;
    continue;
  } else {
    break;
  }
}
const _bind$4 = 256;
const _bind$5 = 280;
let _tmp$3 = _bind$4;
while (true) {
  const i = _tmp$3;
  if (i < _bind$5) {
    if (i >>> 0 < lengths.length) {
      lengths[i] = 7;
    } else {
      $oob();
    }
    _tmp$3 = i + 1 | 0;
    continue;
  } else {
    break;
  }
}
const _M0FP312moonbitstack7moonzip7deflate13fixed__litlen = _M0MP312moonbitstack7moonzip7deflate7Huffman2of(lengths, 288);
function _M0FPC15abort5abortGuE(msg) {
  $panic();
}
function _M0FPC15abort5abortGAyE(msg) {
  return $panic();
}
function _M0FPC15abort5abortGyE(msg) {
  return $panic();
}
function _M0FPC15abort5abortGkE(msg) {
  return $panic();
}
function _M0FPB4rotl(x, r) {
  return x << r | (x >>> (32 - r | 0) | 0);
}
function _M0FPB13consume4__acc(acc, input) {
  return Math.imul(_M0FPB4rotl((acc >>> 0) + ((Math.imul(input, -1028477379) | 0) >>> 0) | 0, 17), 668265263) | 0;
}
function _M0FPB13clamp__offset(offset, len) {
  return offset < 0 ? 0 : offset > len ? len : offset;
}
function _M0MPC15array10FixedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp$4 = 0;
    while (true) {
      const i = _tmp$4;
      if (i < len) {
        const _tmp$5 = dst_offset + i | 0;
        const _tmp$6 = src_offset + i | 0;
        if (_tmp$5 >>> 0 < dst.length) {
          dst[_tmp$5] = _tmp$6 >>> 0 < src.length ? src[_tmp$6] : $oob();
        } else {
          $oob();
        }
        _tmp$4 = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp$4 = len - 1 | 0;
    let _tmp$5 = len > 0;
    while (true) {
      const i = _tmp$4;
      const _more = _tmp$5;
      if (_more) {
        const _tmp$6 = dst_offset + i | 0;
        const _tmp$7 = src_offset + i | 0;
        if (_tmp$6 >>> 0 < dst.length) {
          dst[_tmp$6] = _tmp$7 >>> 0 < src.length ? src[_tmp$7] : $oob();
        } else {
          $oob();
        }
        _tmp$4 = i - 1 | 0;
        _tmp$5 = i > 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGyEE(dst, dst_offset, src, src_offset, len) {
  if (dst === src && dst_offset < src_offset) {
    let _tmp$4 = 0;
    while (true) {
      const i = _tmp$4;
      if (i < len) {
        const _tmp$5 = dst_offset + i | 0;
        const _tmp$6 = src_offset + i | 0;
        if (_tmp$5 >>> 0 < dst.length) {
          dst[_tmp$5] = _tmp$6 >>> 0 < src.length ? src[_tmp$6] : $oob();
        } else {
          $oob();
        }
        _tmp$4 = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp$4 = len - 1 | 0;
    let _tmp$5 = len > 0;
    while (true) {
      const i = _tmp$4;
      const _more = _tmp$5;
      if (_more) {
        const _tmp$6 = dst_offset + i | 0;
        const _tmp$7 = src_offset + i | 0;
        if (_tmp$6 >>> 0 < dst.length) {
          dst[_tmp$6] = _tmp$7 >>> 0 < src.length ? src[_tmp$7] : $oob();
        } else {
          $oob();
        }
        _tmp$4 = i - 1 | 0;
        _tmp$5 = i > 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0MPB18UninitializedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, len) {
  _M0MPC15array10FixedArray12unsafe__blitGRPB17UnsafeMaybeUninitGyEE(dst, dst_offset, src, src_offset, len);
}
function _M0MPB18UninitializedArray23unsafe__make__and__blitGyE(src, allocate_len, src_offset, dst_offset, blit_len) {
  const dst = new Uint8Array(allocate_len);
  _M0MPB18UninitializedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, blit_len);
  return dst;
}
function _M0MPB13StringBuilder13write__objectGRP312moonbitstack7moonrpc5proto7PbErrorE(self, obj) {
  _M0IP312moonbitstack7moonrpc5proto7PbErrorPB4Show6output(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPB13StringBuilder13write__objectGiE(self, obj) {
  _M0IP016_24default__implPB4Show6outputGiE(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPB13StringBuilder13write__objectGRP312moonbitstack7moonvar6prefix7RefusedE(self, obj) {
  _M0IP312moonbitstack7moonvar6prefix7RefusedPB4Show6output(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPB13StringBuilder13write__objectGRP312moonbitstack8moonhttp7huffman7RefusedE(self, obj) {
  _M0IP312moonbitstack8moonhttp7huffman7RefusedPB4Show6output(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPB13StringBuilder13write__objectGlE(self, obj) {
  _M0IP016_24default__implPB4Show6outputGlE(obj, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPC13int3Int16unsafe__to__char(self) {
  return self;
}
function _M0MPB13StringBuilder21StringBuilder_2einner(size_hint) {
  return new _M0TPB13StringBuilder("");
}
function _M0MPB13StringBuilder10to__string(self) {
  return self.val;
}
function _M0IPB13StringBuilderPB6Logger11write__char(self, ch) {
  self.val = `${self.val}${String.fromCodePoint(ch)}`;
}
function _M0IPB13StringBuilderPB6Logger13write__string(self, str) {
  self.val = `${self.val}${str}`;
}
function _M0MPC16uint166UInt1622is__leading__surrogate(self) {
  return self >= 55296 && self <= 56319;
}
function _M0MPC16uint166UInt1623is__trailing__surrogate(self) {
  return self >= 56320 && self <= 57343;
}
function _M0MPC16uint166UInt1616unsafe__to__char(self) {
  return self;
}
function _M0MPC16string10StringView6length(self) {
  return self.end - self.start | 0;
}
function _M0MPC16uint646UInt648to__byte(self) {
  return (Number(BigInt.asIntN(32, self)) | 0) & 255;
}
function _M0MPC13int3Int10to__uint64(self) {
  return BigInt.asUintN(64, BigInt(self));
}
function _M0IP016_24default__implPB2Eq10not__equalGsE(x, y) {
  return !(x === y);
}
function _M0FPB14avalanche__acc(acc) {
  let acc$2 = acc;
  acc$2 = acc$2 ^ (acc$2 >>> 15 | 0);
  acc$2 = Math.imul(acc$2, -2048144777) | 0;
  acc$2 = acc$2 ^ (acc$2 >>> 13 | 0);
  acc$2 = Math.imul(acc$2, -1028477379) | 0;
  acc$2 = acc$2 ^ (acc$2 >>> 16 | 0);
  return acc$2;
}
function _M0FPB13finalize__acc(acc) {
  return _M0FPB14avalanche__acc(acc);
}
function _M0IP016_24default__implPB6Logger28write__string__interpolationGRPB13StringBuilderE(self, show) {
  show.method_table.method_0(show.self, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0IP016_24default__implPB6Logger5writeGRPB13StringBuilderE(self, show) {
  show.method_table.method_0(show.self, { self: self, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
}
function _M0MPC16string6String21clamped__view_2einner(self, start, end) {
  const len = self.length;
  let lo = start < 0 ? 0 : start > len ? len : start;
  let hi;
  if (end === undefined) {
    hi = len;
  } else {
    const _Some = end;
    const _e = _Some;
    hi = _e < 0 ? 0 : _e > len ? len : _e;
  }
  if (lo > 0 && (lo < len && (_M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(lo)) && _M0MPC16uint166UInt1622is__leading__surrogate(self.charCodeAt(lo - 1 | 0))))) {
    lo = lo + 1 | 0;
  }
  if (hi > 0 && (hi < len && (_M0MPC16uint166UInt1623is__trailing__surrogate(self.charCodeAt(hi)) && _M0MPC16uint166UInt1622is__leading__surrogate(self.charCodeAt(hi - 1 | 0))))) {
    hi = hi - 1 | 0;
  }
  return lo >= hi ? new _M0TPC16string10StringView(self, lo, lo) : new _M0TPC16string10StringView(self, lo, hi);
}
function _M0IP016_24default__implPB6Logger16write__substringGRPB13StringBuilderE(self, value, start, len) {
  _M0IPB13StringBuilderPB6Logger11write__view(self, _M0MPC16string6String21clamped__view_2einner(value, start, start + len | 0));
}
function _M0MPC16string10StringView4data(self) {
  return self.str;
}
function _M0MPC16string10StringView13start__offset(self) {
  return self.start;
}
function _M0IP016_24default__implPB4Show6outputGiE(self, logger) {
  logger.method_table.method_0(logger.self, _M0IPC13int3IntPB4Show10to__string(self));
}
function _M0IP016_24default__implPB4Show6outputGlE(self, logger) {
  logger.method_table.method_0(logger.self, _M0IPC15int645Int64PB4Show10to__string(self));
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp5hpack7RefusedE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack8moonhttp5hpack7RefusedPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc6stream11StreamStateE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonrpc6stream11StreamStatePB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc6stream11StreamErrorE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonrpc6stream11StreamErrorPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6leb1287RefusedE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonvar6leb1287RefusedPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc5proto7PbErrorE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonrpc5proto7PbErrorPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc4wire11StatusErrorE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonrpc4wire11StatusErrorPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp7huffman7RefusedE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack8moonhttp7huffman7RefusedPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonvar6prefix7RefusedE(self) {
  const logger = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IP312moonbitstack7moonvar6prefix7RefusedPB4Show6output(self, { self: logger, method_table: _M0FP092moonbitlang_2fcore_2fbuiltin_2fStringBuilder_24as_24_40moonbitlang_2fcore_2fbuiltin_2eLogger });
  return _M0MPB13StringBuilder10to__string(logger);
}
function _M0MPB4Iter4nextGUiRP312moonbitstack7moonrpc6client10ClientCallEE(self) {
  const _func = self.f;
  const result = _func();
  const _bind$6 = self.size_hint;
  if (result === undefined) {
    self.size_hint = _M0MPB4Iter4nextN6constrS112GUiRP312moonbitstack7moonrpc6client10ClientCallEE;
  } else {
    if (_bind$6 === undefined) {
    } else {
      const _Some = _bind$6;
      const _n = _Some;
      self.size_hint = _n > 0 ? _n - 1 | 0 : _M0MPB4Iter4nextN6constrS111GUiRP312moonbitstack7moonrpc6client10ClientCallEE;
    }
  }
  return result;
}
function _M0MPC13int3Int18to__string_2einner(self, radix) {
  return _M0FPB19int__to__string__js(self, radix);
}
function _M0MPC15int645Int6418to__string_2einner(self, radix) {
  return _M0FPB21int64__to__string__js(self, radix);
}
function _M0FPB22index__out__of__boundsGyE(len, index) {
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(60);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "index out of bounds: the len is from 0 to ");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, len);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, " but the index is ");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, index);
  return _M0FPC15abort5abortGyE(_M0MPB13StringBuilder10to__string(_string_builder));
}
function _M0FPB22index__out__of__boundsGkE(len, index) {
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(60);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "index out of bounds: the len is from 0 to ");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, len);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, " but the index is ");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, index);
  return _M0FPC15abort5abortGkE(_M0MPB13StringBuilder10to__string(_string_builder));
}
function _M0MPC16string10StringView2at(self, index) {
  return index >= 0 && index < (self.end - self.start | 0) ? self.str.charCodeAt(self.start + index | 0) : _M0FPB22index__out__of__boundsGkE(self.end - self.start | 0, index);
}
function _M0MPB4Iter3newGUiRP312moonbitstack7moonrpc6client10ClientCallEE(f, size_hint) {
  let size_hint$2;
  if (size_hint === undefined) {
    size_hint$2 = undefined;
  } else {
    const _Some = size_hint;
    const _n = _Some;
    size_hint$2 = _n > 0 ? _n : _M0MPB4Iter3newN6constrS139GUiRP312moonbitstack7moonrpc6client10ClientCallEE;
  }
  return new _M0TPB4IterGUiRP312moonbitstack7moonrpc6client10ClientCallEE(f, size_hint$2);
}
function _M0MPC15array10FixedArray21clamped__view_2einnerGyE(self, start, end) {
  const len = self.length;
  const lo = _M0FPB13clamp__offset(start, len);
  let hi;
  if (end === undefined) {
    hi = len;
  } else {
    const _Some = end;
    const _end = _Some;
    hi = _M0FPB13clamp__offset(_end, len);
  }
  const count = hi > lo ? hi - lo | 0 : 0;
  const _bind$6 = self;
  return new _M0TPB9ArrayViewGyE(_bind$6, lo, lo + count | 0);
}
function _M0MPC14uint4UInt8to__byte(self) {
  return self & 255;
}
function _M0MPC16string10StringView9to__owned(self) {
  return self.str.substring(self.start, self.end);
}
function _M0IPB13StringBuilderPB6Logger11write__view(self, str) {
  self.val = `${self.val}${_M0MPC16string10StringView9to__owned(str)}`;
}
function _M0MPC15array5Array13Array_2einnerGcE(capacity) {
  return [];
}
function _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC15array5Array4pushGcE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0MPC15array5Array4pushGyE(self, value) {
  _M0MPB7JSArray4push(self, value);
}
function _M0IPC16string6StringPB12ToStringView16to__string__view(self) {
  return new _M0TPC16string10StringView(self, 0, self.length);
}
function _M0MPC16string6String9to__array(self) {
  const chars = _M0MPC15array5Array13Array_2einnerGcE(self.length);
  const _bind$6 = self.length;
  let _tmp$4 = 0;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$6) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$7 = self.charCodeAt(_string_index);
        if (_bind$7 >= 55296 && _bind$7 <= 56319 && (_string_index + 1 | 0) < _bind$6) {
          const _bind$8 = self.charCodeAt(_string_index + 1 | 0);
          if (_bind$8 >= 56320 && _bind$8 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$7 - 55296 | 0, 1024) | 0) + _bind$8 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
          break _L;
        }
      }
      _M0MPC15array5Array4pushGcE(chars, _decoded_char);
      _tmp$4 = _decoded_next_string_index;
      continue;
    } else {
      break;
    }
  }
  return chars;
}
function _M0MPC14byte4Byte8to__uint(self) {
  return self;
}
function _M0IPC13int3IntPB4Show10to__string(self) {
  return _M0MPC13int3Int18to__string_2einner(self, 10);
}
function _M0IPC15int645Int64PB4Show10to__string(self) {
  return _M0MPC15int645Int6418to__string_2einner(self, 10);
}
function _M0MPC15array9ArrayView4joinGsE(self, separator) {
  if ((self.end - self.start | 0) === 0) {
    return "";
  } else {
    const _hd = self.buf[self.start];
    const _x_buf = self.buf;
    const _x_start = 1 + self.start | 0;
    const _x_end = self.end;
    const hd = _M0IPC16string6StringPB12ToStringView16to__string__view(_hd);
    const _bind$6 = _x_end - _x_start | 0;
    let size_hint;
    let _tmp$4 = 0;
    let _tmp$5 = hd.end - hd.start | 0;
    while (true) {
      const _ = _tmp$4;
      const size_hint$2 = _tmp$5;
      if (_ < _bind$6) {
        const s = _x_buf[_x_start + _ | 0];
        _tmp$4 = _ + 1 | 0;
        const _bind$7 = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
        _tmp$5 = (size_hint$2 + (_bind$7.end - _bind$7.start | 0) | 0) + (separator.end - separator.start | 0) | 0;
        continue;
      } else {
        size_hint = size_hint$2;
        break;
      }
    }
    const size_hint$2 = size_hint << 1;
    const buf = _M0MPB13StringBuilder21StringBuilder_2einner(size_hint$2);
    _M0IPB13StringBuilderPB6Logger11write__view(buf, hd);
    if ((separator.end - separator.start | 0) === 0) {
      const _bind$7 = _x_end - _x_start | 0;
      let _tmp$6 = 0;
      while (true) {
        const _ = _tmp$6;
        if (_ < _bind$7) {
          const s = _x_buf[_x_start + _ | 0];
          const s$2 = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, s$2);
          _tmp$6 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    } else {
      const _bind$7 = _x_end - _x_start | 0;
      let _tmp$6 = 0;
      while (true) {
        const _ = _tmp$6;
        if (_ < _bind$7) {
          const s = _x_buf[_x_start + _ | 0];
          const s$2 = _M0IPC16string6StringPB12ToStringView16to__string__view(s);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, separator);
          _M0IPB13StringBuilderPB6Logger11write__view(buf, s$2);
          _tmp$6 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    }
    return _M0MPB13StringBuilder10to__string(buf);
  }
}
function _M0MPC16option6Option6unwrapGiE(self) {
  if (self === undefined) {
    return $panic();
  } else {
    const _Some = self;
    return _Some;
  }
}
function _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(self) {
  if (self === undefined) {
    return $panic();
  } else {
    const _Some = self;
    return _Some;
  }
}
function _M0MPC16option6Option3mapGjiE(self, f) {
  if (self === undefined) {
    return undefined;
  } else {
    const _Some = self;
    const _t = _Some;
    return f(_t);
  }
}
function _M0FPB21calc__grow__threshold(capacity) {
  if (16 === 0) {
    $panic();
  }
  return (Math.imul(capacity, 13) | 0) / 16 | 0;
}
function _M0MPC13int3Int20next__power__of__two(self) {
  if (self >= 0) {
    if (self <= 1) {
      return 1;
    }
    if (self > 1073741824) {
      return 1073741824;
    }
    return (2147483647 >> (Math.clz32(self - 1 | 0) - 1 | 0)) + 1 | 0;
  } else {
    return $panic();
  }
}
function _M0FPB8new__mapGsRP312moonbitstack7moonrpc6stream7HandlerE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind$6 = capacity$2 - 1 | 0;
  const _bind$7 = _M0FPB21calc__grow__threshold(capacity$2);
  const _bind$8 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$9 = undefined;
  return new _M0TPB3MapGsRP312moonbitstack7moonrpc6stream7HandlerE(_bind$8, 0, capacity$2, _bind$6, _bind$7, _bind$9, -1);
}
function _M0FPB8new__mapGiRP312moonbitstack7moonrpc6server9SrvStreamE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind$6 = capacity$2 - 1 | 0;
  const _bind$7 = _M0FPB21calc__grow__threshold(capacity$2);
  const _bind$8 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$9 = undefined;
  return new _M0TPB3MapGiRP312moonbitstack7moonrpc6server9SrvStreamE(_bind$8, 0, capacity$2, _bind$6, _bind$7, _bind$9, -1);
}
function _M0FPB8new__mapGiRP312moonbitstack7moonrpc6client10ClientCallE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind$6 = capacity$2 - 1 | 0;
  const _bind$7 = _M0FPB21calc__grow__threshold(capacity$2);
  const _bind$8 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$9 = undefined;
  return new _M0TPB3MapGiRP312moonbitstack7moonrpc6client10ClientCallE(_bind$8, 0, capacity$2, _bind$6, _bind$7, _bind$9, -1);
}
function _M0FPB8new__mapGiRPC16buffer6BufferE(capacity) {
  const capacity$2 = _M0MPC13int3Int20next__power__of__two(capacity);
  const _bind$6 = capacity$2 - 1 | 0;
  const _bind$7 = _M0FPB21calc__grow__threshold(capacity$2);
  const _bind$8 = $make_array_len_and_init(capacity$2, undefined);
  const _bind$9 = undefined;
  return new _M0TPB3MapGiRPC16buffer6BufferE(_bind$8, 0, capacity$2, _bind$6, _bind$7, _bind$9, -1);
}
function _M0FPB21capacity__for__length(length) {
  let capacity = _M0MPC13int3Int20next__power__of__two(length);
  if (length > _M0FPB21calc__grow__threshold(capacity)) {
    capacity = Math.imul(capacity, 2) | 0;
  }
  return capacity;
}
function _M0MPC13int3Int3max(self, other) {
  return self > other ? self : other;
}
function _M0MPB3Map20add__entry__to__tailGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, entry) {
  const _bind$6 = self.tail;
  if (_bind$6 === -1) {
    self.head = entry;
  } else {
    const _tmp$4 = self.entries;
    _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6 >>> 0 < _tmp$4.length ? _tmp$4[_bind$6] : $oob()).next = entry;
  }
  self.tail = idx;
  self.entries[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, entry) {
  const _bind$6 = self.tail;
  if (_bind$6 === -1) {
    self.head = entry;
  } else {
    const _tmp$4 = self.entries;
    _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6 >>> 0 < _tmp$4.length ? _tmp$4[_bind$6] : $oob()).next = entry;
  }
  self.tail = idx;
  self.entries[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, entry) {
  const _bind$6 = self.tail;
  if (_bind$6 === -1) {
    self.head = entry;
  } else {
    const _tmp$4 = self.entries;
    _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6 >>> 0 < _tmp$4.length ? _tmp$4[_bind$6] : $oob()).next = entry;
  }
  self.tail = idx;
  self.entries[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map20add__entry__to__tailGiRPC16buffer6BufferE(self, idx, entry) {
  const _bind$6 = self.tail;
  if (_bind$6 === -1) {
    self.head = entry;
  } else {
    const _tmp$4 = self.entries;
    _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6 >>> 0 < _tmp$4.length ? _tmp$4[_bind$6] : $oob()).next = entry;
  }
  self.tail = idx;
  self.entries[idx] = entry;
  self.size = self.size + 1 | 0;
}
function _M0MPB3Map10set__entryGsRP312moonbitstack7moonrpc6stream7HandlerE(self, entry, new_idx) {
  const _bind$6 = entry.next;
  if (_bind$6 === undefined) {
    self.tail = new_idx;
  } else {
    const _Some = _bind$6;
    const _next = _Some;
    _next.prev = new_idx;
  }
  self.entries[new_idx] = entry;
}
function _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, entry, new_idx) {
  const _bind$6 = entry.next;
  if (_bind$6 === undefined) {
    self.tail = new_idx;
  } else {
    const _Some = _bind$6;
    const _next = _Some;
    _next.prev = new_idx;
  }
  self.entries[new_idx] = entry;
}
function _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6client10ClientCallE(self, entry, new_idx) {
  const _bind$6 = entry.next;
  if (_bind$6 === undefined) {
    self.tail = new_idx;
  } else {
    const _Some = _bind$6;
    const _next = _Some;
    _next.prev = new_idx;
  }
  self.entries[new_idx] = entry;
}
function _M0MPB3Map10set__entryGiRPC16buffer6BufferE(self, entry, new_idx) {
  const _bind$6 = entry.next;
  if (_bind$6 === undefined) {
    self.tail = new_idx;
  } else {
    const _Some = _bind$6;
    const _next = _Some;
    _next.prev = new_idx;
  }
  self.entries[new_idx] = entry;
}
function _M0MPB3Map10push__awayGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, entry) {
  let _tmp$4 = entry.psl + 1 | 0;
  let _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
  let _tmp$6 = entry;
  while (true) {
    const psl = _tmp$4;
    const idx$2 = _tmp$5;
    const entry$2 = _tmp$6;
    const _bind$6 = self.entries[idx$2];
    if (_bind$6 === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGsRP312moonbitstack7moonrpc6stream7HandlerE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGsRP312moonbitstack7moonrpc6stream7HandlerE(self, entry$2, idx$2);
        _tmp$4 = _curr_entry.psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        _tmp$6 = _curr_entry;
        continue;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, entry) {
  let _tmp$4 = entry.psl + 1 | 0;
  let _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
  let _tmp$6 = entry;
  while (true) {
    const psl = _tmp$4;
    const idx$2 = _tmp$5;
    const entry$2 = _tmp$6;
    const _bind$6 = self.entries[idx$2];
    if (_bind$6 === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, entry$2, idx$2);
        _tmp$4 = _curr_entry.psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        _tmp$6 = _curr_entry;
        continue;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, entry) {
  let _tmp$4 = entry.psl + 1 | 0;
  let _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
  let _tmp$6 = entry;
  while (true) {
    const psl = _tmp$4;
    const idx$2 = _tmp$5;
    const entry$2 = _tmp$6;
    const _bind$6 = self.entries[idx$2];
    if (_bind$6 === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6client10ClientCallE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGiRP312moonbitstack7moonrpc6client10ClientCallE(self, entry$2, idx$2);
        _tmp$4 = _curr_entry.psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        _tmp$6 = _curr_entry;
        continue;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map10push__awayGiRPC16buffer6BufferE(self, idx, entry) {
  let _tmp$4 = entry.psl + 1 | 0;
  let _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
  let _tmp$6 = entry;
  while (true) {
    const psl = _tmp$4;
    const idx$2 = _tmp$5;
    const entry$2 = _tmp$6;
    const _bind$6 = self.entries[idx$2];
    if (_bind$6 === undefined) {
      entry$2.psl = psl;
      _M0MPB3Map10set__entryGiRPC16buffer6BufferE(self, entry$2, idx$2);
      return;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (psl > _curr_entry.psl) {
        entry$2.psl = psl;
        _M0MPB3Map10set__entryGiRPC16buffer6BufferE(self, entry$2, idx$2);
        _tmp$4 = _curr_entry.psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        _tmp$6 = _curr_entry;
        continue;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx$2 + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map20rehash__place__entryGsRP312moonbitstack7moonrpc6stream7HandlerE(self, outer) {
  const hash = outer.hash;
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      outer.psl = psl;
      outer.prev = self.tail;
      _M0MPB3Map20add__entry__to__tailGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, outer);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr = _Some;
      if (psl > _curr.psl) {
        _M0MPB3Map10push__awayGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, _curr);
        outer.psl = psl;
        outer.prev = self.tail;
        _M0MPB3Map20add__entry__to__tailGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, outer);
        return undefined;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map20rehash__place__entryGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, outer) {
  const hash = outer.hash;
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      outer.psl = psl;
      outer.prev = self.tail;
      _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, outer);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr = _Some;
      if (psl > _curr.psl) {
        _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, _curr);
        outer.psl = psl;
        outer.prev = self.tail;
        _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, outer);
        return undefined;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map20rehash__place__entryGiRP312moonbitstack7moonrpc6client10ClientCallE(self, outer) {
  const hash = outer.hash;
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      outer.psl = psl;
      outer.prev = self.tail;
      _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, outer);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr = _Some;
      if (psl > _curr.psl) {
        _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, _curr);
        outer.psl = psl;
        outer.prev = self.tail;
        _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, outer);
        return undefined;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map20rehash__place__entryGiRPC16buffer6BufferE(self, outer) {
  const hash = outer.hash;
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      outer.psl = psl;
      outer.prev = self.tail;
      _M0MPB3Map20add__entry__to__tailGiRPC16buffer6BufferE(self, idx, outer);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr = _Some;
      if (psl > _curr.psl) {
        _M0MPB3Map10push__awayGiRPC16buffer6BufferE(self, idx, _curr);
        outer.psl = psl;
        outer.prev = self.tail;
        _M0MPB3Map20add__entry__to__tailGiRPC16buffer6BufferE(self, idx, outer);
        return undefined;
      } else {
        _tmp$4 = psl + 1 | 0;
        _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
        continue;
      }
    }
  }
}
function _M0MPB3Map4growGsRP312moonbitstack7moonrpc6stream7HandlerE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  self.grow_at = _M0FPB21calc__grow__threshold(self.capacity);
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp$4 = old_head;
  while (true) {
    const x = _tmp$4;
    if (x === undefined) {
      return;
    } else {
      const _Some = x;
      const _e = _Some;
      const next_in_chain = _e.next;
      _e.next = undefined;
      _M0MPB3Map20rehash__place__entryGsRP312moonbitstack7moonrpc6stream7HandlerE(self, _e);
      _tmp$4 = next_in_chain;
      continue;
    }
  }
}
function _M0MPB3Map4growGiRP312moonbitstack7moonrpc6server9SrvStreamE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  self.grow_at = _M0FPB21calc__grow__threshold(self.capacity);
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp$4 = old_head;
  while (true) {
    const x = _tmp$4;
    if (x === undefined) {
      return;
    } else {
      const _Some = x;
      const _e = _Some;
      const next_in_chain = _e.next;
      _e.next = undefined;
      _M0MPB3Map20rehash__place__entryGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, _e);
      _tmp$4 = next_in_chain;
      continue;
    }
  }
}
function _M0MPB3Map4growGiRP312moonbitstack7moonrpc6client10ClientCallE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  self.grow_at = _M0FPB21calc__grow__threshold(self.capacity);
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp$4 = old_head;
  while (true) {
    const x = _tmp$4;
    if (x === undefined) {
      return;
    } else {
      const _Some = x;
      const _e = _Some;
      const next_in_chain = _e.next;
      _e.next = undefined;
      _M0MPB3Map20rehash__place__entryGiRP312moonbitstack7moonrpc6client10ClientCallE(self, _e);
      _tmp$4 = next_in_chain;
      continue;
    }
  }
}
function _M0MPB3Map4growGiRPC16buffer6BufferE(self) {
  const old_head = self.head;
  const new_capacity = self.capacity << 1;
  self.entries = $make_array_len_and_init(new_capacity, undefined);
  self.capacity = new_capacity;
  self.capacity_mask = new_capacity - 1 | 0;
  self.grow_at = _M0FPB21calc__grow__threshold(self.capacity);
  self.size = 0;
  self.head = undefined;
  self.tail = -1;
  let _tmp$4 = old_head;
  while (true) {
    const x = _tmp$4;
    if (x === undefined) {
      return;
    } else {
      const _Some = x;
      const _e = _Some;
      const next_in_chain = _e.next;
      _e.next = undefined;
      _M0MPB3Map20rehash__place__entryGiRPC16buffer6BufferE(self, _e);
      _tmp$4 = next_in_chain;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGsRP312moonbitstack7moonrpc6stream7HandlerE(self, key, value, hash) {
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGsRP312moonbitstack7moonrpc6stream7HandlerE(self);
        _tmp$4 = 0;
        _tmp$5 = hash & self.capacity_mask;
        continue;
      }
      const _bind$7 = self.tail;
      const _bind$8 = undefined;
      const entry = new _M0TPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerE(_bind$7, _bind$8, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGsRP312moonbitstack7moonrpc6stream7HandlerE(self);
          _tmp$4 = 0;
          _tmp$5 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, _curr_entry);
        const _bind$7 = self.tail;
        const _bind$8 = undefined;
        const entry = new _M0TPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerE(_bind$7, _bind$8, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGsRP312moonbitstack7moonrpc6stream7HandlerE(self, idx, entry);
        return undefined;
      }
      _tmp$4 = psl + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, key, value, hash) {
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGiRP312moonbitstack7moonrpc6server9SrvStreamE(self);
        _tmp$4 = 0;
        _tmp$5 = hash & self.capacity_mask;
        continue;
      }
      const _bind$7 = self.tail;
      const _bind$8 = undefined;
      const entry = new _M0TPB5EntryGiRP312moonbitstack7moonrpc6server9SrvStreamE(_bind$7, _bind$8, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGiRP312moonbitstack7moonrpc6server9SrvStreamE(self);
          _tmp$4 = 0;
          _tmp$5 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, _curr_entry);
        const _bind$7 = self.tail;
        const _bind$8 = undefined;
        const entry = new _M0TPB5EntryGiRP312moonbitstack7moonrpc6server9SrvStreamE(_bind$7, _bind$8, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, idx, entry);
        return undefined;
      }
      _tmp$4 = psl + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGiRP312moonbitstack7moonrpc6client10ClientCallE(self, key, value, hash) {
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGiRP312moonbitstack7moonrpc6client10ClientCallE(self);
        _tmp$4 = 0;
        _tmp$5 = hash & self.capacity_mask;
        continue;
      }
      const _bind$7 = self.tail;
      const _bind$8 = undefined;
      const entry = new _M0TPB5EntryGiRP312moonbitstack7moonrpc6client10ClientCallE(_bind$7, _bind$8, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGiRP312moonbitstack7moonrpc6client10ClientCallE(self);
          _tmp$4 = 0;
          _tmp$5 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, _curr_entry);
        const _bind$7 = self.tail;
        const _bind$8 = undefined;
        const entry = new _M0TPB5EntryGiRP312moonbitstack7moonrpc6client10ClientCallE(_bind$7, _bind$8, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGiRP312moonbitstack7moonrpc6client10ClientCallE(self, idx, entry);
        return undefined;
      }
      _tmp$4 = psl + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map15set__with__hashGiRPC16buffer6BufferE(self, key, value, hash) {
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const psl = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      if (self.size >= self.grow_at) {
        _M0MPB3Map4growGiRPC16buffer6BufferE(self);
        _tmp$4 = 0;
        _tmp$5 = hash & self.capacity_mask;
        continue;
      }
      const _bind$7 = self.tail;
      const _bind$8 = undefined;
      const entry = new _M0TPB5EntryGiRPC16buffer6BufferE(_bind$7, _bind$8, psl, hash, key, value);
      _M0MPB3Map20add__entry__to__tailGiRPC16buffer6BufferE(self, idx, entry);
      return undefined;
    } else {
      const _Some = _bind$6;
      const _curr_entry = _Some;
      if (_curr_entry.hash === hash && _curr_entry.key === key) {
        _curr_entry.value = value;
        return undefined;
      }
      if (psl > _curr_entry.psl) {
        if (self.size >= self.grow_at) {
          _M0MPB3Map4growGiRPC16buffer6BufferE(self);
          _tmp$4 = 0;
          _tmp$5 = hash & self.capacity_mask;
          continue;
        }
        _M0MPB3Map10push__awayGiRPC16buffer6BufferE(self, idx, _curr_entry);
        const _bind$7 = self.tail;
        const _bind$8 = undefined;
        const entry = new _M0TPB5EntryGiRPC16buffer6BufferE(_bind$7, _bind$8, psl, hash, key, value);
        _M0MPB3Map20add__entry__to__tailGiRPC16buffer6BufferE(self, idx, entry);
        return undefined;
      }
      _tmp$4 = psl + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self, key, value) {
  _M0MPB3Map15set__with__hashGsRP312moonbitstack7moonrpc6stream7HandlerE(self, key, value, _M0IPC16string6StringPB4Hash4hash(key));
}
function _M0MPB3Map3setGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, key, value) {
  _M0MPB3Map15set__with__hashGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, key, value, _M0IPC13int3IntPB4Hash4hash(key));
}
function _M0MPB3Map3setGiRP312moonbitstack7moonrpc6client10ClientCallE(self, key, value) {
  _M0MPB3Map15set__with__hashGiRP312moonbitstack7moonrpc6client10ClientCallE(self, key, value, _M0IPC13int3IntPB4Hash4hash(key));
}
function _M0MPB3Map3setGiRPC16buffer6BufferE(self, key, value) {
  _M0MPB3Map15set__with__hashGiRPC16buffer6BufferE(self, key, value, _M0IPC13int3IntPB4Hash4hash(key));
}
function _M0MPB3Map3MapGsRP312moonbitstack7moonrpc6stream7HandlerE(arr, capacity) {
  const length = arr.end - arr.start | 0;
  let capacity$2;
  if (capacity === undefined) {
    capacity$2 = length === 0 ? 8 : _M0FPB21capacity__for__length(length);
  } else {
    const _Some = capacity;
    const _capacity = _Some;
    capacity$2 = _M0MPC13int3Int3max(_capacity, _M0FPB21capacity__for__length(length));
  }
  const m = _M0FPB8new__mapGsRP312moonbitstack7moonrpc6stream7HandlerE(capacity$2);
  const _bind$6 = arr.end - arr.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(m, e._0, e._1);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map3MapGiRP312moonbitstack7moonrpc6server9SrvStreamE(arr, capacity) {
  const length = arr.end - arr.start | 0;
  let capacity$2;
  if (capacity === undefined) {
    capacity$2 = length === 0 ? 8 : _M0FPB21capacity__for__length(length);
  } else {
    const _Some = capacity;
    const _capacity = _Some;
    capacity$2 = _M0MPC13int3Int3max(_capacity, _M0FPB21capacity__for__length(length));
  }
  const m = _M0FPB8new__mapGiRP312moonbitstack7moonrpc6server9SrvStreamE(capacity$2);
  const _bind$6 = arr.end - arr.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGiRP312moonbitstack7moonrpc6server9SrvStreamE(m, e._0, e._1);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map3MapGiRP312moonbitstack7moonrpc6client10ClientCallE(arr, capacity) {
  const length = arr.end - arr.start | 0;
  let capacity$2;
  if (capacity === undefined) {
    capacity$2 = length === 0 ? 8 : _M0FPB21capacity__for__length(length);
  } else {
    const _Some = capacity;
    const _capacity = _Some;
    capacity$2 = _M0MPC13int3Int3max(_capacity, _M0FPB21capacity__for__length(length));
  }
  const m = _M0FPB8new__mapGiRP312moonbitstack7moonrpc6client10ClientCallE(capacity$2);
  const _bind$6 = arr.end - arr.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGiRP312moonbitstack7moonrpc6client10ClientCallE(m, e._0, e._1);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map3MapGiRPC16buffer6BufferE(arr, capacity) {
  const length = arr.end - arr.start | 0;
  let capacity$2;
  if (capacity === undefined) {
    capacity$2 = length === 0 ? 8 : _M0FPB21capacity__for__length(length);
  } else {
    const _Some = capacity;
    const _capacity = _Some;
    capacity$2 = _M0MPC13int3Int3max(_capacity, _M0FPB21capacity__for__length(length));
  }
  const m = _M0FPB8new__mapGiRPC16buffer6BufferE(capacity$2);
  const _bind$6 = arr.end - arr.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const e = arr.buf[arr.start + _ | 0];
      _M0MPB3Map3setGiRPC16buffer6BufferE(m, e._0, e._1);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return m;
}
function _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self, key) {
  const hash = _M0IPC13int3IntPB4Hash4hash(key);
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      return undefined;
    } else {
      const _Some = _bind$6;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp$4 = i + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self, key) {
  const hash = _M0IPC13int3IntPB4Hash4hash(key);
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      return undefined;
    } else {
      const _Some = _bind$6;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp$4 = i + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGiRPC16buffer6BufferE(self, key) {
  const hash = _M0IPC13int3IntPB4Hash4hash(key);
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      return undefined;
    } else {
      const _Some = _bind$6;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp$4 = i + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map3getGsRP312moonbitstack7moonrpc6stream7HandlerE(self, key) {
  const hash = _M0IPC16string6StringPB4Hash4hash(key);
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      return undefined;
    } else {
      const _Some = _bind$6;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        return _entry.value;
      }
      if (i > _entry.psl) {
        return undefined;
      }
      _tmp$4 = i + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map13remove__entryGiRPC16buffer6BufferE(self, entry) {
  const _bind$6 = entry.prev;
  if (_bind$6 === -1) {
    self.head = entry.next;
  } else {
    const _tmp$4 = self.entries;
    _M0MPC16option6Option6unwrapGRPB5EntryGsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6 >>> 0 < _tmp$4.length ? _tmp$4[_bind$6] : $oob()).next = entry.next;
  }
  const _bind$7 = entry.next;
  if (_bind$7 === undefined) {
    self.tail = entry.prev;
    return;
  } else {
    const _Some = _bind$7;
    const _next = _Some;
    _next.prev = entry.prev;
    return;
  }
}
function _M0MPB3Map11shift__backGiRPC16buffer6BufferE(self, idx) {
  let _tmp$4 = idx;
  while (true) {
    const cur = _tmp$4;
    const next = (cur + 1 | 0) & self.capacity_mask;
    _L: {
      const _bind$6 = self.entries[next];
      if (_bind$6 === undefined) {
        break _L;
      } else {
        const _Some = _bind$6;
        const _x = _Some;
        const _x$2 = _x.psl;
        if (_x$2 === 0) {
          break _L;
        } else {
          _x.psl = _x.psl - 1 | 0;
          _M0MPB3Map10set__entryGiRPC16buffer6BufferE(self, _x, cur);
          _tmp$4 = next;
          continue;
        }
      }
    }
    self.entries[cur] = undefined;
    return;
  }
}
function _M0MPB3Map18remove__with__hashGiRPC16buffer6BufferE(self, key, hash) {
  let _tmp$4 = 0;
  let _tmp$5 = hash & self.capacity_mask;
  while (true) {
    const i = _tmp$4;
    const idx = _tmp$5;
    const _bind$6 = self.entries[idx];
    if (_bind$6 === undefined) {
      return;
    } else {
      const _Some = _bind$6;
      const _entry = _Some;
      if (_entry.hash === hash && _entry.key === key) {
        _M0MPB3Map13remove__entryGiRPC16buffer6BufferE(self, _entry);
        _M0MPB3Map11shift__backGiRPC16buffer6BufferE(self, idx);
        self.size = self.size - 1 | 0;
        return;
      }
      if (i > _entry.psl) {
        return;
      }
      _tmp$4 = i + 1 | 0;
      _tmp$5 = (idx + 1 | 0) & self.capacity_mask;
      continue;
    }
  }
}
function _M0MPB3Map6removeGiRPC16buffer6BufferE(self, key) {
  _M0MPB3Map18remove__with__hashGiRPC16buffer6BufferE(self, key, _M0IPC13int3IntPB4Hash4hash(key));
}
function _M0MPB3Map4iterGiRP312moonbitstack7moonrpc6client10ClientCallE(self) {
  const curr_entry = new _M0TPB8MutLocalGORPB5EntryGiRP312moonbitstack7moonrpc6client10ClientCallEE(self.head);
  const len = self.size;
  const remaining = new _M0TPB8MutLocalGiE(len);
  return _M0MPB4Iter3newGUiRP312moonbitstack7moonrpc6client10ClientCallEE(() => {
    _L: {
      if (remaining.val > 0) {
        const _bind$6 = curr_entry.val;
        if (_bind$6 === undefined) {
          break _L;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          const _key = _x.key;
          const _value = _x.value;
          const _next = _x.next;
          curr_entry.val = _next;
          remaining.val = remaining.val - 1 | 0;
          return { _0: _key, _1: _value };
        }
      } else {
        break _L;
      }
    }
    return undefined;
  }, len);
}
function _M0MPB3Map4iterGiRP312moonbitstack7moonrpc6server9SrvStreamE(self) {
  const curr_entry = new _M0TPB8MutLocalGORPB5EntryGiRP312moonbitstack7moonrpc6server9SrvStreamEE(self.head);
  const len = self.size;
  const remaining = new _M0TPB8MutLocalGiE(len);
  return _M0MPB4Iter3newGUiRP312moonbitstack7moonrpc6client10ClientCallEE(() => {
    _L: {
      if (remaining.val > 0) {
        const _bind$6 = curr_entry.val;
        if (_bind$6 === undefined) {
          break _L;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          const _key = _x.key;
          const _value = _x.value;
          const _next = _x.next;
          curr_entry.val = _next;
          remaining.val = remaining.val - 1 | 0;
          return { _0: _key, _1: _value };
        }
      } else {
        break _L;
      }
    }
    return undefined;
  }, len);
}
function _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6client10ClientCallE(self) {
  return _M0MPB3Map4iterGiRP312moonbitstack7moonrpc6client10ClientCallE(self);
}
function _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6server9SrvStreamE(self) {
  return _M0MPB3Map4iterGiRP312moonbitstack7moonrpc6server9SrvStreamE(self);
}
function _M0IPC14byte4BytePB2Eq5equal(self, that) {
  return self === that;
}
function _M0MPC15bytes9BytesView6length(self) {
  return self.end - self.start | 0;
}
function _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6client10ClientCallE(self) {
  return _M0MPB4Iter4nextGUiRP312moonbitstack7moonrpc6client10ClientCallEE(self);
}
function _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6server9SrvStreamE(self) {
  return _M0MPB4Iter4nextGUiRP312moonbitstack7moonrpc6client10ClientCallEE(self);
}
function _M0IPC16string6StringPB4Hash4hash(self) {
  let acc = (_M0FPB4seed >>> 0) + (374761393 >>> 0) | 0;
  const _bind$6 = self.length;
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$6) {
      acc = (acc >>> 0) + (4 >>> 0) | 0;
      const v = self.charCodeAt(i);
      acc = _M0FPB13consume4__acc(acc, v);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0FPB13finalize__acc(acc);
}
function _M0IPC13int3IntPB4Hash4hash(self) {
  const acc = (((_M0FPB4seed >>> 0) + (374761393 >>> 0) | 0) >>> 0) + (4 >>> 0) | 0;
  return _M0FPB13finalize__acc(_M0FPB13consume4__acc(acc, self));
}
function _M0MPC15array10FixedArray23unsafe__make__and__blitGyE(src, allocate_len, init, src_offset, dst_offset, blit_len) {
  const dst = $makebytes(allocate_len, init);
  _M0MPC15array10FixedArray12unsafe__blitGyE(dst, dst_offset, src, src_offset, blit_len);
  return dst;
}
function _M0MPC15array10FixedArray23make__and__blit_2einnerGyE(src, allocate_len, init, len, src_offset, dst_offset) {
  if (allocate_len >= 0 && (len >= 0 && (src_offset >= 0 && (dst_offset >= 0 && ((src_offset + len | 0) <= src.length && (dst_offset + len | 0) <= allocate_len))))) {
    return _M0MPC15array10FixedArray23unsafe__make__and__blitGyE(src, allocate_len, init, src_offset, dst_offset, len);
  } else {
    const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(89);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "bounds check failed: allocate_len = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, allocate_len);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", src_offset = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, src_offset);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", dst_offset = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, dst_offset);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", len = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, len);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", src.length = ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, src.length);
    return _M0FPC15abort5abortGAyE(_M0MPB13StringBuilder10to__string(_string_builder));
  }
}
function _M0MPC15bytes9BytesView2at(self, index) {
  return index >= 0 && index < (self.end - self.start | 0) ? self.buf[self.start + index | 0] : _M0FPB22index__out__of__boundsGyE(self.end - self.start | 0, index);
}
function _M0MPC15bytes5Bytes21clamped__view_2einner(self, start, end) {
  const len = self.length;
  const lo = _M0FPB13clamp__offset(start, len);
  let hi;
  if (end === undefined) {
    hi = len;
  } else {
    const _Some = end;
    const _end = _Some;
    hi = _M0FPB13clamp__offset(_end, len);
  }
  const count = hi > lo ? hi - lo | 0 : 0;
  return new _M0TPC15bytes9BytesView(self, lo, lo + count | 0);
}
function _M0MPC15bytes9BytesView21clamped__view_2einner(self, start, end) {
  const len = self.end - self.start | 0;
  const lo = _M0FPB13clamp__offset(start, len);
  let hi;
  if (end === undefined) {
    hi = len;
  } else {
    const _Some = end;
    const _end = _Some;
    hi = _M0FPB13clamp__offset(_end, len);
  }
  const count = hi > lo ? hi - lo | 0 : 0;
  const _bind$6 = self.buf;
  const _bind$7 = self.start + lo | 0;
  return new _M0TPC15bytes9BytesView(_bind$6, _bind$7, _bind$7 + count | 0);
}
function _M0MPC15bytes9BytesView4data(self) {
  return self.buf;
}
function _M0MPC15bytes9BytesView13start__offset(self) {
  return self.start;
}
function _M0MPC15array10FixedArray17blit__from__bytes(self, bytes_offset, src, src_offset, length) {
  const len1 = self.length;
  const len2 = src.length;
  if (length >= 0 && (bytes_offset >= 0 && (bytes_offset <= len1 && (length <= (len1 - bytes_offset | 0) && (src_offset >= 0 && (src_offset <= len2 && length <= (len2 - src_offset | 0))))))) {
    _M0MPC15array10FixedArray12unsafe__blitGyE(self, bytes_offset, src, src_offset, length);
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15bytes9BytesView9to__owned(self) {
  if ((self.end - self.start | 0) === self.buf.length) {
    return self.buf;
  }
  const bytes = $makebytes(self.end - self.start | 0, 0);
  _M0MPC15array10FixedArray17blit__from__bytes(bytes, 0, self.buf, _M0MPC15bytes9BytesView13start__offset(self), self.end - self.start | 0);
  return bytes;
}
function _M0MPC15bytes5Bytes11from__array(arr) {
  const len = arr.end - arr.start | 0;
  if (len === 0) {
    return $bytes_literal$0;
  }
  const result = _M0MPB18UninitializedArray23unsafe__make__and__blitGyE(arr.buf, len, arr.start, 0, len);
  return result;
}
function _M0MPC15bytes5Bytes16bytes__add__impl(self, other) {
  const len_self = self.length;
  const len_other = other.length;
  const rv = $makebytes(len_self + len_other | 0, 0);
  _M0MPC15array10FixedArray17blit__from__bytes(rv, 0, self, 0, len_self);
  _M0MPC15array10FixedArray17blit__from__bytes(rv, len_self, other, 0, len_other);
  return rv;
}
function _M0IPC15bytes5BytesPB3Add3add(self, other) {
  return _M0MPC15bytes5Bytes16bytes__add__impl(self, other);
}
function _M0MPC15array5Array28unsafe__truncate__to__lengthGzE(self, new_len) {
  _M0MPB7JSArray11set__length(self, new_len);
}
function _M0MPC15array5Array6removeGUzzEE(self, index) {
  if (index >= 0 && index < self.length) {
    const value = index >>> 0 < self.length ? self[index] : $oob();
    _M0MPB7JSArray6splice(self, index, 1);
    return value;
  } else {
    const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(60);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "index out of bounds: the len is from 0 to ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, self.length);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, " but the index is ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, index);
    return _M0FPC15abort5abortGAyE(_M0MPB13StringBuilder10to__string(_string_builder));
  }
}
function _M0MPC15array5Array6insertGUzzEE(self, index, value) {
  if (index >= 0 && index <= self.length) {
    _M0MPB7JSArray7splice1(self, index, 0, value);
    return;
  } else {
    const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(60);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "index out of bounds: the len is from 0 to ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, self.length);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, " but the index is ");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, index);
    _M0FPC15abort5abortGuE(_M0MPB13StringBuilder10to__string(_string_builder));
    return;
  }
}
function _M0MPC15array5Array2atGsE(self, index) {
  const len = self.length;
  return index >= 0 && index < len ? self[index] : $panic();
}
function _M0MPC15array5Array2atGcE(self, index) {
  const len = self.length;
  return index >= 0 && index < len ? self[index] : $panic();
}
function _M0MPC15array5Array2atGyE(self, index) {
  const len = self.length;
  return index >= 0 && index < len ? self[index] : $panic();
}
function _M0MPC15array5Array2atGiE(self, index) {
  const len = self.length;
  return index >= 0 && index < len ? self[index] : $panic();
}
function _M0MPC15array5Array3setGyE(self, index, value) {
  const len = self.length;
  if (index >= 0 && index < len) {
    self[index] = value;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array3setGiE(self, index, value) {
  const len = self.length;
  if (index >= 0 && index < len) {
    self[index] = value;
    return;
  } else {
    $panic();
    return;
  }
}
function _M0MPC15array5Array4makeGyE(len, elem) {
  const arr = new Array(len);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < len) {
      arr[i] = elem;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15array5Array4makeGiE(len, elem) {
  const arr = new Array(len);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < len) {
      arr[i] = elem;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return arr;
}
function _M0MPC15array5Array5clearGzE(self) {
  _M0MPC15array5Array28unsafe__truncate__to__lengthGzE(self, 0);
}
function _M0MPC15array5Array4joinGsE(self, separator) {
  return _M0MPC15array9ArrayView4joinGsE(new _M0TPB9ArrayViewGsE(self, 0, self.length), separator);
}
function _M0FPC28encoding4utf814encode_2einner(str, bom) {
  return _M0FPC28encoding4utf816encode__utf8__js(_M0MPC16string10StringView4data(str), _M0MPC16string10StringView13start__offset(str), str.end - str.start | 0, bom);
}
function _M0FPC28encoding4utf821utf8__find__malformed(src, src_offset, src_length) {
  const view = _M0MPC15bytes5Bytes21clamped__view_2einner(src, src_offset, src_offset + src_length | 0);
  let _tmp$4 = view;
  while (true) {
    const bytes = _tmp$4;
    let malformed;
    _L: {
      let rest;
      _L$2: {
        let rest$2;
        _L$3: {
          let rest$3;
          _L$4: {
            let rest$4;
            _L$5: {
              if ((bytes.end - bytes.start | 0) === 0) {
                return -1;
              } else {
                if ((bytes.end - bytes.start | 0) >= 8) {
                  const _x = bytes.buf[bytes.start];
                  if (_x <= 127) {
                    const _x$2 = bytes.buf[bytes.start + 1 | 0];
                    if (_x$2 <= 127) {
                      const _x$3 = bytes.buf[bytes.start + 2 | 0];
                      if (_x$3 <= 127) {
                        const _x$4 = bytes.buf[bytes.start + 3 | 0];
                        if (_x$4 <= 127) {
                          const _x$5 = bytes.buf[bytes.start + 4 | 0];
                          if (_x$5 <= 127) {
                            const _x$6 = bytes.buf[bytes.start + 5 | 0];
                            if (_x$6 <= 127) {
                              const _x$7 = bytes.buf[bytes.start + 6 | 0];
                              if (_x$7 <= 127) {
                                const _x$8 = bytes.buf[bytes.start + 7 | 0];
                                if (_x$8 <= 127) {
                                  const _x$9 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 8 | 0, bytes.end);
                                  _tmp$4 = _x$9;
                                  continue;
                                } else {
                                  const _x$9 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                                  rest$4 = _x$9;
                                  break _L$5;
                                }
                              } else {
                                const _x$8 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                                rest$4 = _x$8;
                                break _L$5;
                              }
                            } else {
                              const _x$7 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                              rest$4 = _x$7;
                              break _L$5;
                            }
                          } else {
                            const _x$6 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                            rest$4 = _x$6;
                            break _L$5;
                          }
                        } else {
                          const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                          rest$4 = _x$5;
                          break _L$5;
                        }
                      } else {
                        const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                        rest$4 = _x$4;
                        break _L$5;
                      }
                    } else {
                      const _x$3 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                      rest$4 = _x$3;
                      break _L$5;
                    }
                  } else {
                    if (_x >= 194 && _x <= 223) {
                      const _x$2 = bytes.buf[bytes.start + 1 | 0];
                      if (_x$2 >= 128 && _x$2 <= 191) {
                        const _x$3 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 2 | 0, bytes.end);
                        rest$3 = _x$3;
                        break _L$4;
                      } else {
                        malformed = bytes;
                        break _L;
                      }
                    } else {
                      if (_x === 224) {
                        const _x$2 = bytes.buf[bytes.start + 1 | 0];
                        if (_x$2 >= 160 && _x$2 <= 191) {
                          const _x$3 = bytes.buf[bytes.start + 2 | 0];
                          if (_x$3 >= 128 && _x$3 <= 191) {
                            const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                            rest$2 = _x$4;
                            break _L$3;
                          } else {
                            malformed = bytes;
                            break _L;
                          }
                        } else {
                          malformed = bytes;
                          break _L;
                        }
                      } else {
                        if (_x >= 225 && _x <= 236) {
                          const _x$2 = bytes.buf[bytes.start + 1 | 0];
                          if (_x$2 >= 128 && _x$2 <= 191) {
                            const _x$3 = bytes.buf[bytes.start + 2 | 0];
                            if (_x$3 >= 128 && _x$3 <= 191) {
                              const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                              rest$2 = _x$4;
                              break _L$3;
                            } else {
                              malformed = bytes;
                              break _L;
                            }
                          } else {
                            malformed = bytes;
                            break _L;
                          }
                        } else {
                          if (_x === 237) {
                            const _x$2 = bytes.buf[bytes.start + 1 | 0];
                            if (_x$2 >= 128 && _x$2 <= 159) {
                              const _x$3 = bytes.buf[bytes.start + 2 | 0];
                              if (_x$3 >= 128 && _x$3 <= 191) {
                                const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                rest$2 = _x$4;
                                break _L$3;
                              } else {
                                malformed = bytes;
                                break _L;
                              }
                            } else {
                              malformed = bytes;
                              break _L;
                            }
                          } else {
                            if (_x >= 238 && _x <= 239) {
                              const _x$2 = bytes.buf[bytes.start + 1 | 0];
                              if (_x$2 >= 128 && _x$2 <= 191) {
                                const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                if (_x$3 >= 128 && _x$3 <= 191) {
                                  const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                  rest$2 = _x$4;
                                  break _L$3;
                                } else {
                                  malformed = bytes;
                                  break _L;
                                }
                              } else {
                                malformed = bytes;
                                break _L;
                              }
                            } else {
                              if (_x === 240) {
                                const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                if (_x$2 >= 144 && _x$2 <= 191) {
                                  const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                  if (_x$3 >= 128 && _x$3 <= 191) {
                                    const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                    if (_x$4 >= 128 && _x$4 <= 191) {
                                      const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                      rest = _x$5;
                                      break _L$2;
                                    } else {
                                      malformed = bytes;
                                      break _L;
                                    }
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                } else {
                                  malformed = bytes;
                                  break _L;
                                }
                              } else {
                                if (_x >= 241 && _x <= 243) {
                                  const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                  if (_x$2 >= 128 && _x$2 <= 191) {
                                    const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                    if (_x$3 >= 128 && _x$3 <= 191) {
                                      const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                      if (_x$4 >= 128 && _x$4 <= 191) {
                                        const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                        rest = _x$5;
                                        break _L$2;
                                      } else {
                                        malformed = bytes;
                                        break _L;
                                      }
                                    } else {
                                      malformed = bytes;
                                      break _L;
                                    }
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                } else {
                                  if (_x === 244) {
                                    const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                    if (_x$2 >= 128 && _x$2 <= 143) {
                                      const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                      if (_x$3 >= 128 && _x$3 <= 191) {
                                        const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                        if (_x$4 >= 128 && _x$4 <= 191) {
                                          const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                          rest = _x$5;
                                          break _L$2;
                                        } else {
                                          malformed = bytes;
                                          break _L;
                                        }
                                      } else {
                                        malformed = bytes;
                                        break _L;
                                      }
                                    } else {
                                      malformed = bytes;
                                      break _L;
                                    }
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                } else {
                  const _x = bytes.buf[bytes.start];
                  if (_x >= 0 && _x <= 127) {
                    const _x$2 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 1 | 0, bytes.end);
                    rest$4 = _x$2;
                    break _L$5;
                  } else {
                    if ((bytes.end - bytes.start | 0) >= 2) {
                      if (_x >= 194 && _x <= 223) {
                        const _x$2 = bytes.buf[bytes.start + 1 | 0];
                        if (_x$2 >= 128 && _x$2 <= 191) {
                          const _x$3 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 2 | 0, bytes.end);
                          rest$3 = _x$3;
                          break _L$4;
                        } else {
                          (bytes.end - bytes.start | 0) >= 3;
                          malformed = bytes;
                          break _L;
                        }
                      } else {
                        if ((bytes.end - bytes.start | 0) >= 3) {
                          if (_x === 224) {
                            const _x$2 = bytes.buf[bytes.start + 1 | 0];
                            if (_x$2 >= 160 && _x$2 <= 191) {
                              const _x$3 = bytes.buf[bytes.start + 2 | 0];
                              if (_x$3 >= 128 && _x$3 <= 191) {
                                const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                rest$2 = _x$4;
                                break _L$3;
                              } else {
                                malformed = bytes;
                                break _L;
                              }
                            } else {
                              malformed = bytes;
                              break _L;
                            }
                          } else {
                            if (_x >= 225 && _x <= 236) {
                              const _x$2 = bytes.buf[bytes.start + 1 | 0];
                              if (_x$2 >= 128 && _x$2 <= 191) {
                                const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                if (_x$3 >= 128 && _x$3 <= 191) {
                                  const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                  rest$2 = _x$4;
                                  break _L$3;
                                } else {
                                  malformed = bytes;
                                  break _L;
                                }
                              } else {
                                malformed = bytes;
                                break _L;
                              }
                            } else {
                              if (_x === 237) {
                                const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                if (_x$2 >= 128 && _x$2 <= 159) {
                                  const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                  if (_x$3 >= 128 && _x$3 <= 191) {
                                    const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                    rest$2 = _x$4;
                                    break _L$3;
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                } else {
                                  malformed = bytes;
                                  break _L;
                                }
                              } else {
                                if (_x >= 238 && _x <= 239) {
                                  const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                  if (_x$2 >= 128 && _x$2 <= 191) {
                                    const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                    if (_x$3 >= 128 && _x$3 <= 191) {
                                      const _x$4 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
                                      rest$2 = _x$4;
                                      break _L$3;
                                    } else {
                                      malformed = bytes;
                                      break _L;
                                    }
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                } else {
                                  if ((bytes.end - bytes.start | 0) >= 4) {
                                    if (_x === 240) {
                                      const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                      if (_x$2 >= 144 && _x$2 <= 191) {
                                        const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                        if (_x$3 >= 128 && _x$3 <= 191) {
                                          const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                          if (_x$4 >= 128 && _x$4 <= 191) {
                                            const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                            rest = _x$5;
                                            break _L$2;
                                          } else {
                                            malformed = bytes;
                                            break _L;
                                          }
                                        } else {
                                          malformed = bytes;
                                          break _L;
                                        }
                                      } else {
                                        malformed = bytes;
                                        break _L;
                                      }
                                    } else {
                                      if (_x >= 241 && _x <= 243) {
                                        const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                        if (_x$2 >= 128 && _x$2 <= 191) {
                                          const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                          if (_x$3 >= 128 && _x$3 <= 191) {
                                            const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                            if (_x$4 >= 128 && _x$4 <= 191) {
                                              const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                              rest = _x$5;
                                              break _L$2;
                                            } else {
                                              malformed = bytes;
                                              break _L;
                                            }
                                          } else {
                                            malformed = bytes;
                                            break _L;
                                          }
                                        } else {
                                          malformed = bytes;
                                          break _L;
                                        }
                                      } else {
                                        if (_x === 244) {
                                          const _x$2 = bytes.buf[bytes.start + 1 | 0];
                                          if (_x$2 >= 128 && _x$2 <= 143) {
                                            const _x$3 = bytes.buf[bytes.start + 2 | 0];
                                            if (_x$3 >= 128 && _x$3 <= 191) {
                                              const _x$4 = bytes.buf[bytes.start + 3 | 0];
                                              if (_x$4 >= 128 && _x$4 <= 191) {
                                                const _x$5 = new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 4 | 0, bytes.end);
                                                rest = _x$5;
                                                break _L$2;
                                              } else {
                                                malformed = bytes;
                                                break _L;
                                              }
                                            } else {
                                              malformed = bytes;
                                              break _L;
                                            }
                                          } else {
                                            malformed = bytes;
                                            break _L;
                                          }
                                        } else {
                                          malformed = bytes;
                                          break _L;
                                        }
                                      }
                                    }
                                  } else {
                                    malformed = bytes;
                                    break _L;
                                  }
                                }
                              }
                            }
                          }
                        } else {
                          malformed = bytes;
                          break _L;
                        }
                      }
                    } else {
                      malformed = bytes;
                      break _L;
                    }
                  }
                }
              }
            }
            _tmp$4 = rest$4;
            continue;
          }
          _tmp$4 = rest$3;
          continue;
        }
        _tmp$4 = rest$2;
        continue;
      }
      _tmp$4 = rest;
      continue;
    }
    return _M0MPC15bytes9BytesView13start__offset(malformed) - src_offset | 0;
  }
}
function _M0FPC28encoding4utf825strict__malformed__suffix(bytes) {
  const input = _M0MPC15bytes9BytesView4data(bytes);
  const src_offset = _M0MPC15bytes9BytesView13start__offset(bytes);
  const src_length = bytes.end - bytes.start | 0;
  const malformed_offset = _M0FPC28encoding4utf821utf8__find__malformed(input, src_offset, src_length);
  return _M0MPC15bytes9BytesView21clamped__view_2einner(bytes, malformed_offset, undefined);
}
function _M0FPC28encoding4utf815drop__utf8__bom(bytes, ignore_bom) {
  _L: {
    if (ignore_bom) {
      _L$2: {
        if ((bytes.end - bytes.start | 0) >= 3) {
          const _x = bytes.buf[bytes.start];
          if (_x === 239) {
            const _x$2 = bytes.buf[bytes.start + 1 | 0];
            if (_x$2 === 187) {
              const _x$3 = bytes.buf[bytes.start + 2 | 0];
              if (_x$3 === 191) {
                return new _M0TPC15bytes9BytesView(bytes.buf, bytes.start + 3 | 0, bytes.end);
              } else {
                break _L$2;
              }
            } else {
              break _L$2;
            }
          } else {
            break _L$2;
          }
        } else {
          break _L$2;
        }
      }
      break _L;
    } else {
      break _L;
    }
  }
  return bytes;
}
function _M0FPC28encoding4utf814decode_2einner(bytes, ignore_bom) {
  const result = _M0FPC28encoding4utf816decode__utf8__js(_M0MPC15bytes9BytesView4data(bytes), _M0MPC15bytes9BytesView13start__offset(bytes), bytes.end - bytes.start | 0, !ignore_bom);
  if (result.length === 1) {
    return new _M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE2Ok(0 >>> 0 < result.length ? result[0] : $oob());
  } else {
    const bytes$2 = _M0FPC28encoding4utf815drop__utf8__bom(bytes, ignore_bom);
    return new _M0DTPC16result6ResultGsRPC28encoding4utf89MalformedE3Err(new _M0DTPC15error5Error60moonbitlang_2fcore_2fencoding_2futf8_2eMalformed_2eMalformed(_M0FPC28encoding4utf825strict__malformed__suffix(bytes$2)));
  }
}
function _M0FPC28encoding4utf821decode__lossy_2einner(bytes, ignore_bom) {
  return _M0FPC28encoding4utf823decode__utf8__lossy__js(_M0MPC15bytes9BytesView4data(bytes), _M0MPC15bytes9BytesView13start__offset(bytes), bytes.end - bytes.start | 0, !ignore_bom);
}
function _M0FPC16buffer24buffer__growth__capacity(current, len, required) {
  if (required < len) {
    _M0FPC15abort5abortGuE("Buffer capacity overflow");
  }
  const start = current <= 0 ? 1 : current;
  let _tmp$4 = start;
  while (true) {
    const space = _tmp$4;
    if (space >= required) {
      return space;
    }
    const next = Math.imul(space, 2) | 0;
    if (next <= space) {
      return required;
    }
    _tmp$4 = next;
    continue;
  }
}
function _M0MPC16buffer6Buffer4grow(self, required) {
  const new_capacity = _M0FPC16buffer24buffer__growth__capacity(self.data.length, self.len, required);
  const new_data = _M0MPC15array10FixedArray23make__and__blit_2einnerGyE(self.data, new_capacity, 0, self.len, 0, 0);
  self.data = new_data;
}
function _M0MPC16buffer6Buffer9to__bytes(self) {
  return _M0MPC15bytes5Bytes11from__array(_M0MPC15array10FixedArray21clamped__view_2einnerGyE(self.data, 0, self.len));
}
function _M0MPC16buffer6Buffer14Buffer_2einner(size_hint) {
  const initial = size_hint < 1 ? 1 : size_hint;
  const data = $makebytes(initial, 0);
  return new _M0TPC16buffer6Buffer(data, 0);
}
function _M0MPC16buffer6Buffer16write__bytesview(self, value) {
  const val_len = value.end - value.start | 0;
  const required = self.len + val_len | 0;
  if (required > self.data.length || required < self.len) {
    _M0MPC16buffer6Buffer4grow(self, required);
  }
  _M0MPC15array10FixedArray17blit__from__bytes(self.data, self.len, _M0MPC15bytes9BytesView4data(value), _M0MPC15bytes9BytesView13start__offset(value), value.end - value.start | 0);
  self.len = self.len + val_len | 0;
}
function _M0MPC16buffer6Buffer12write__bytes(self, value) {
  _M0MPC16buffer6Buffer16write__bytesview(self, value);
}
function _M0MPC16buffer6Buffer6length(self) {
  return self.len;
}
function _M0MPC16buffer6Buffer11write__byte(self, value) {
  if (self.len >= self.data.length) {
    _M0MPC16buffer6Buffer4grow(self, self.len + 1 | 0);
  }
  self.data[self.len] = value;
  self.len = self.len + 1 | 0;
}
function _M0MPC16buffer6Buffer5reset(self) {
  self.len = 0;
}
function _M0FPC13cmp7minimumGiE(x, y) {
  return x > y ? y : x;
}
function _M0MP312moonbitstack8moonhttp6header6Header12cost_2einner(self, overhead) {
  return (self.name.length + self.value.length | 0) + overhead | 0;
}
function _M0IP312moonbitstack8moonhttp7huffman7RefusedPB4Show6output(self, logger) {
  let m;
  _L: {
    let m$2;
    _L$2: {
      switch (self.$tag) {
        case 8: {
          logger.method_table.method_0(logger.self, "Eos");
          return;
        }
        case 7: {
          const _Padding = self;
          const _m = _Padding._0;
          m$2 = _m;
          break _L$2;
        }
        default: {
          const _Malformed = self;
          const _m$2 = _Malformed._0;
          m = _m$2;
          break _L;
        }
      }
    }
    logger.method_table.method_0(logger.self, `Padding(${m$2})`);
    return;
  }
  logger.method_table.method_0(logger.self, `Malformed(${m})`);
}
function _M0FP312moonbitstack8moonhttp7huffman5build() {
  const nodes = [new _M0TP312moonbitstack8moonhttp7huffman4Node(-1, -1, -1)];
  let _tmp$4 = 0;
  while (true) {
    const sym = _tmp$4;
    if (sym < _M0FP312moonbitstack8moonhttp7huffman5table.length) {
      let code;
      let bits;
      _L: {
        const _bind$6 = _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman5table, sym);
        const _code = _bind$6._0;
        const _bits = _bind$6._1;
        code = _code;
        bits = _bits;
        break _L;
      }
      const cur = new _M0TPB8MutLocalGiE(0);
      let _tmp$5 = bits - 1 | 0;
      while (true) {
        const i = _tmp$5;
        if (i >= 0) {
          const bit = code >> i & 1;
          const next = bit === 0 ? _M0MPC15array5Array2atGsE(nodes, cur.val).zero : _M0MPC15array5Array2atGsE(nodes, cur.val).one;
          let child;
          if (next === -1) {
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(nodes, new _M0TP312moonbitstack8moonhttp7huffman4Node(-1, -1, -1));
            const idx = nodes.length - 1 | 0;
            if (bit === 0) {
              _M0MPC15array5Array2atGsE(nodes, cur.val).zero = idx;
            } else {
              _M0MPC15array5Array2atGsE(nodes, cur.val).one = idx;
            }
            child = idx;
          } else {
            child = next;
          }
          cur.val = child;
          _tmp$5 = i - 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _M0MPC15array5Array2atGsE(nodes, cur.val).sym = sym;
      _tmp$4 = sym + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return nodes;
}
function _M0FP312moonbitstack8moonhttp7huffman6encode(input) {
  const out$2 = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  const acc = new _M0TPB8MutLocalGmE(0n);
  const nbits = new _M0TPB8MutLocalGiE(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _M0MPC15bytes9BytesView6length(input)) {
      let code;
      let bits;
      _L: {
        const _bind$6 = _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman5table, _M0MPC15bytes9BytesView2at(input, i));
        const _code = _bind$6._0;
        const _bits = _bind$6._1;
        code = _code;
        bits = _bits;
        break _L;
      }
      acc.val = BigInt.asUintN(64, BigInt.asUintN(64, acc.val << BigInt(bits & 63)) | _M0MPC13int3Int10to__uint64(code));
      nbits.val = nbits.val + bits | 0;
      while (true) {
        if (nbits.val >= 8) {
          nbits.val = nbits.val - 8 | 0;
          _M0MPC16buffer6Buffer11write__byte(out$2, (Number(BigInt.asIntN(32, BigInt.asUintN(64, BigInt.asUintN(64, BigInt.asUintN(64, acc.val) >> BigInt(nbits.val & 63)) & 255n))) | 0) & 255);
          continue;
        } else {
          break;
        }
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (nbits.val > 0) {
    const pad = 8 - nbits.val | 0;
    acc.val = BigInt.asUintN(64, BigInt.asUintN(64, acc.val << BigInt(pad & 63)) | _M0MPC13int3Int10to__uint64((1 << pad) - 1 | 0));
    _M0MPC16buffer6Buffer11write__byte(out$2, (Number(BigInt.asIntN(32, BigInt.asUintN(64, acc.val & 255n))) | 0) & 255);
  }
  return _M0MPC16buffer6Buffer9to__bytes(out$2);
}
function _M0FP312moonbitstack8moonhttp7huffman4size(input) {
  const bits = new _M0TPB8MutLocalGiE(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _M0MPC15bytes9BytesView6length(input)) {
      bits.val = bits.val + _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman5table, _M0MPC15bytes9BytesView2at(input, i))._1 | 0;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (8 === 0) {
    $panic();
  }
  return (bits.val + 7 | 0) / 8 | 0;
}
function _M0FP312moonbitstack8moonhttp7huffman6decode(input) {
  const out$2 = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  const node = new _M0TPB8MutLocalGiE(0);
  const since = new _M0TPB8MutLocalGiE(0);
  const all_ones = new _M0TPB8MutLocalGbE(true);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _M0MPC15bytes9BytesView6length(input)) {
      const octet = _M0MPC15bytes9BytesView2at(input, i);
      let _tmp$5 = 7;
      while (true) {
        const b = _tmp$5;
        if (b >= 0) {
          const bit = octet >> b & 1;
          since.val = since.val + 1 | 0;
          if (bit === 0) {
            all_ones.val = false;
          }
          node.val = bit === 0 ? _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman4trie, node.val).zero : _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman4trie, node.val).one;
          if (node.val === -1) {
            return new _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err(new _M0DTPC15error5Error55moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eMalformed("the bits leave the code space"));
          }
          const sym = _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp7huffman4trie, node.val).sym;
          if (sym >= 0) {
            if (sym === _M0FP312moonbitstack8moonhttp7huffman3eos) {
              return new _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err(_M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2eEos__);
            }
            _M0MPC16buffer6Buffer11write__byte(out$2, sym & 255);
            node.val = 0;
            since.val = 0;
            all_ones.val = true;
          }
          _tmp$5 = b - 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (node.val !== 0) {
    if (since.val >= 8) {
      return new _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2ePadding("more than seven bits"));
    }
    if (!all_ones.val) {
      return new _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhuffman_2eRefused_2ePadding("not a run of ones"));
    }
  }
  return new _M0DTPC16result6ResultGzRP312moonbitstack8moonhttp7huffman7RefusedE2Ok(_M0MPC16buffer6Buffer9to__bytes(out$2));
}
function _M0IP312moonbitstack7moonvar6prefix7RefusedPB4Show6output(self, logger) {
  let limit;
  let got;
  _L: {
    let m;
    _L$2: {
      if (self.$tag === 5) {
        const _Truncated = self;
        const _m = _Truncated._0;
        m = _m;
        break _L$2;
      } else {
        const _Exceeded = self;
        const _limit = _Exceeded._0;
        const _got = _Exceeded._1;
        limit = _limit;
        got = _got;
        break _L;
      }
    }
    logger.method_table.method_0(logger.self, `Truncated(${m})`);
    return;
  }
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(22);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "Exceeded(limit=");
  _M0MPB13StringBuilder13write__objectGlE(_string_builder, limit);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", got=");
  _M0MPB13StringBuilder13write__objectGlE(_string_builder, got);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ")");
  logger.method_table.method_0(logger.self, _M0MPB13StringBuilder10to__string(_string_builder));
}
function _M0FP312moonbitstack7moonvar6prefix14encode_2einner(v, prefix, flags) {
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  const ceiling = (1 << prefix) - 1 | 0;
  if (v < ceiling) {
    _M0MPC16buffer6Buffer11write__byte(buf, (flags | v) & 255);
  } else {
    _M0MPC16buffer6Buffer11write__byte(buf, (flags | ceiling) & 255);
    const rest = new _M0TPB8MutLocalGiE(v - ceiling | 0);
    while (true) {
      if (rest.val >= 128) {
        if (128 === 0) {
          $panic();
        }
        _M0MPC16buffer6Buffer11write__byte(buf, ((rest.val % 128 | 0) + 128 | 0) & 255);
        if (128 === 0) {
          $panic();
        }
        rest.val = rest.val / 128 | 0;
        continue;
      } else {
        break;
      }
    }
    _M0MPC16buffer6Buffer11write__byte(buf, rest.val & 255);
  }
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP312moonbitstack7moonvar6prefix14decode_2einner(b, at, prefix) {
  if (at < 0 || at >= _M0MPC15bytes9BytesView6length(b)) {
    return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonvar_2fprefix_2eRefused_2eTruncated("no prefix octet"));
  }
  const ceiling = (1 << prefix) - 1 | 0;
  const first = _M0MPC15bytes9BytesView2at(b, at) & ceiling;
  if (first < ceiling) {
    return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE2Ok({ _0: first, _1: 1 });
  }
  const out$2 = new _M0TPB8MutLocalGlE(BigInt.asUintN(64, BigInt(ceiling)));
  const shift = new _M0TPB8MutLocalGiE(0);
  const used = new _M0TPB8MutLocalGiE(1);
  while (true) {
    if ((at + used.val | 0) >= _M0MPC15bytes9BytesView6length(b)) {
      return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonvar_2fprefix_2eRefused_2eTruncated("the value continues past the end"));
    }
    if (shift.val >= 35) {
      return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err(new _M0DTPC15error5Error52moonbitstack_2fmoonvar_2fprefix_2eRefused_2eExceeded(_M0FP312moonbitstack7moonvar6prefix5limit, out$2.val));
    }
    const octet = _M0MPC15bytes9BytesView2at(b, at + used.val | 0);
    used.val = used.val + 1 | 0;
    out$2.val = BigInt.asUintN(64, out$2.val + BigInt.asUintN(64, BigInt.asUintN(64, BigInt(octet & 127)) * BigInt.asUintN(64, 1n << BigInt(shift.val & 63))));
    shift.val = shift.val + 7 | 0;
    if (BigInt.asIntN(64, out$2.val) > BigInt.asIntN(64, _M0FP312moonbitstack7moonvar6prefix5limit)) {
      return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE3Err(new _M0DTPC15error5Error52moonbitstack_2fmoonvar_2fprefix_2eRefused_2eExceeded(_M0FP312moonbitstack7moonvar6prefix5limit, out$2.val));
    }
    if ((octet & 128) === 0) {
      break;
    }
    continue;
  }
  return new _M0DTPC16result6ResultGUiiERP312moonbitstack7moonvar6prefix7RefusedE2Ok({ _0: Number(BigInt.asIntN(32, out$2.val)) | 0, _1: used.val });
}
function _M0FP312moonbitstack7moonvar6prefix15flagged_2einner(b, at, bit) {
  return at >= 0 && (at < _M0MPC15bytes9BytesView6length(b) && (_M0MPC15bytes9BytesView2at(b, at) & 1 << bit) !== 0);
}
function _M0IP312moonbitstack8moonhttp5hpack7RefusedPB4Show6output(self, logger) {
  let limit;
  let got;
  _L: {
    let got$2;
    _L$2: {
      let m;
      _L$3: {
        switch (self.$tag) {
          case 11: {
            const _Malformed = self;
            const _m = _Malformed._0;
            m = _m;
            break _L$3;
          }
          case 10: {
            const _Index = self;
            const _got = _Index._0;
            got$2 = _got;
            break _L$2;
          }
          default: {
            const _Exceeded = self;
            const _limit = _Exceeded._0;
            const _got$2 = _Exceeded._1;
            limit = _limit;
            got = _got$2;
            break _L;
          }
        }
      }
      logger.method_table.method_0(logger.self, `Malformed(${m})`);
      return;
    }
    const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(11);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "Index(got=");
    _M0MPB13StringBuilder13write__objectGiE(_string_builder, got$2);
    _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ")");
    logger.method_table.method_0(logger.self, _M0MPB13StringBuilder10to__string(_string_builder));
    return;
  }
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(22);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "Exceeded(limit=");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, limit);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", got=");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, got);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ")");
  logger.method_table.method_0(logger.self, _M0MPB13StringBuilder10to__string(_string_builder));
}
function _M0FP312moonbitstack8moonhttp5hpack6octets(s) {
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < s.length) {
      _M0MPC16buffer6Buffer11write__byte(buf, (i >>> 0 < s.length ? s.charCodeAt(i) : $oob()) & 255);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP312moonbitstack8moonhttp5hpack14string_2einner(octets, huffman) {
  const plain = _M0MPC15bytes9BytesView9to__owned(octets);
  if (huffman && _M0FP312moonbitstack8moonhttp7huffman4size(octets) <= _M0MPC15bytes9BytesView6length(octets)) {
    const coded = _M0FP312moonbitstack8moonhttp7huffman6encode(octets);
    const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
    const _bind$6 = _M0FP312moonbitstack7moonvar6prefix14encode_2einner(coded.length, 7, 128);
    _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length));
    _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(coded, 0, coded.length));
    return _M0MPC16buffer6Buffer9to__bytes(buf);
  } else {
    const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
    const _bind$6 = _M0FP312moonbitstack7moonvar6prefix14encode_2einner(plain.length, 7, 0);
    _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length));
    _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(plain, 0, plain.length));
    return _M0MPC16buffer6Buffer9to__bytes(buf);
  }
}
function _M0FP312moonbitstack8moonhttp5hpack5reach(b, at, prefix) {
  let _try_err;
  _L: {
    const _bind$6 = _M0FP312moonbitstack7moonvar6prefix14decode_2einner(b, at, prefix);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(_tmp$4);
  }
  const e = _try_err;
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(18);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "a prefix integer: ");
  _M0MPB13StringBuilder13write__objectGRP312moonbitstack7moonvar6prefix7RefusedE(_string_builder, e);
  return new _M0DTPC16result6ResultGUiiERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed(_M0MPB13StringBuilder10to__string(_string_builder)));
}
function _M0FP312moonbitstack8moonhttp5hpack13read__literal(data, offset) {
  let len;
  let int_len;
  _L: {
    const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack5reach(data, offset, 7);
    let _bind$7;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _bind$7 = _ok._0;
    } else {
      return _bind$6;
    }
    const _len = _bind$7._0;
    const _int_len = _bind$7._1;
    len = _len;
    int_len = _int_len;
    break _L;
  }
  const start = offset + int_len | 0;
  if (start > _M0MPC15bytes9BytesView6length(data) || len > (_M0MPC15bytes9BytesView6length(data) - start | 0)) {
    return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed("HPACK string literal runs past the block"));
  }
  return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE2Ok({ _0: _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes9BytesView21clamped__view_2einner(data, start, start + len | 0)), _1: int_len + len | 0 });
}
function _M0FP312moonbitstack8moonhttp5hpack12read__string(data, offset) {
  const huff = _M0FP312moonbitstack7moonvar6prefix15flagged_2einner(data, offset, 7);
  let raw;
  let consumed;
  _L: {
    const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack13read__literal(data, offset);
    let _bind$7;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _bind$7 = _ok._0;
    } else {
      return _bind$6;
    }
    const _raw = _bind$7._0;
    const _consumed = _bind$7._1;
    raw = _raw;
    consumed = _consumed;
    break _L;
  }
  let _tmp$4;
  if (huff) {
    let _tmp$5;
    let _try_err;
    _L$2: {
      _L$3: {
        const _bind$6 = _M0FP312moonbitstack8moonhttp7huffman6decode(new _M0TPC15bytes9BytesView(raw, 0, raw.length));
        if (_bind$6.$tag === 1) {
          const _ok = _bind$6;
          _tmp$5 = _ok._0;
        } else {
          const _err = _bind$6;
          _try_err = _err._0;
          break _L$3;
        }
        break _L$2;
      }
      const e = _try_err;
      const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(26);
      _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "a Huffman string literal: ");
      _M0MPB13StringBuilder13write__objectGRP312moonbitstack8moonhttp7huffman7RefusedE(_string_builder, e);
      return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed(_M0MPB13StringBuilder10to__string(_string_builder)));
    }
    _tmp$4 = { _0: _tmp$5, _1: consumed };
  } else {
    _tmp$4 = { _0: raw, _1: consumed };
  }
  return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(_tmp$4);
}
function _M0MP312moonbitstack8moonhttp5hpack5Table11new_2einner(limit) {
  return new _M0TP312moonbitstack8moonhttp5hpack5Table([], 0, limit);
}
function _M0FP312moonbitstack8moonhttp5hpack4cost(name, value) {
  return (name.length + value.length | 0) + 32 | 0;
}
function _M0MP312moonbitstack8moonhttp5hpack5Table5evict(self) {
  while (true) {
    if (self.size > self.limit && self.entries.length > 0) {
      const old = _M0MPC15array5Array6removeGUzzEE(self.entries, self.entries.length - 1 | 0);
      self.size = self.size - _M0FP312moonbitstack8moonhttp5hpack4cost(old._0, old._1) | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0MP312moonbitstack8moonhttp5hpack5Table6resize(self, limit) {
  self.limit = limit;
  _M0MP312moonbitstack8moonhttp5hpack5Table5evict(self);
}
function _M0MP312moonbitstack8moonhttp5hpack5Table3add(self, name, value) {
  const sz = _M0FP312moonbitstack8moonhttp5hpack4cost(name, value);
  while (true) {
    if ((self.size + sz | 0) > self.limit && self.entries.length > 0) {
      const old = _M0MPC15array5Array6removeGUzzEE(self.entries, self.entries.length - 1 | 0);
      self.size = self.size - _M0FP312moonbitstack8moonhttp5hpack4cost(old._0, old._1) | 0;
      continue;
    } else {
      break;
    }
  }
  if (sz <= self.limit) {
    _M0MPC15array5Array6insertGUzzEE(self.entries, 0, { _0: name, _1: value });
    self.size = self.size + sz | 0;
    return;
  } else {
    return;
  }
}
function _M0FP312moonbitstack8moonhttp5hpack6lookup(dt, index) {
  const fixed = _M0FP312moonbitstack8moonhttp5hpack13static__table.length;
  if (index >= 1 && index <= fixed) {
    return _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp5hpack13static__table, index - 1 | 0);
  } else {
    const d = (index - fixed | 0) - 1 | 0;
    return d >= 0 && d < dt.entries.length ? new _M0TP312moonbitstack8moonhttp6header6Header(_M0MPC15array5Array2atGsE(dt.entries, d)._0, _M0MPC15array5Array2atGsE(dt.entries, d)._1) : undefined;
  }
}
function _M0MP312moonbitstack8moonhttp5hpack7Decoder11new_2einner(limit) {
  return new _M0TP312moonbitstack8moonhttp5hpack7Decoder(_M0MP312moonbitstack8moonhttp5hpack5Table11new_2einner(limit), limit);
}
function _M0MP312moonbitstack8moonhttp5hpack7Decoder3new(limit$46$opt) {
  let limit;
  if (limit$46$opt === undefined) {
    limit = _M0FP312moonbitstack8moonhttp5hpack5limit;
  } else {
    const _Some = limit$46$opt;
    limit = _Some;
  }
  return _M0MP312moonbitstack8moonhttp5hpack7Decoder11new_2einner(limit);
}
function _M0MP312moonbitstack8moonhttp5hpack7Decoder10read__name(self, block, index, off) {
  if (index === 0) {
    return _M0FP312moonbitstack8moonhttp5hpack12read__string(block, off);
  } else {
    let header;
    _L: {
      const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack6lookup(self.table, index);
      if (_bind$6 === undefined) {
        return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eIndex(index));
      } else {
        const _Some = _bind$6;
        const _header = _Some;
        header = _header;
        break _L;
      }
    }
    return new _M0DTPC16result6ResultGUziERP312moonbitstack8moonhttp5hpack7RefusedE2Ok({ _0: header.name, _1: 0 });
  }
}
function _M0MP312moonbitstack8moonhttp5hpack7Decoder6decode(self, block, limit) {
  const out$2 = [];
  const size = new _M0TPB8MutLocalGiE(0);
  const off = new _M0TPB8MutLocalGiE(0);
  const n = _M0MPC15bytes9BytesView6length(block);
  const keep = (h) => {
    size.val = size.val + _M0MP312moonbitstack8moonhttp6header6Header12cost_2einner(h, 32) | 0;
    _L: {
      let l;
      _L$2: {
        if (limit === undefined) {
          break _L;
        } else {
          const _Some = limit;
          const _l = _Some;
          if (size.val > _l) {
            l = _l;
            break _L$2;
          } else {
            break _L;
          }
        }
      }
      return;
    }
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out$2, h);
  };
  while (true) {
    if (off.val < n) {
      const b = _M0MPC15bytes9BytesView2at(block, off.val);
      if ((b & 128) !== 0) {
        let index;
        let consumed;
        _L: {
          const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack5reach(block, off.val, 7);
          let _bind$7;
          if (_bind$6.$tag === 1) {
            const _ok = _bind$6;
            _bind$7 = _ok._0;
          } else {
            return _bind$6;
          }
          const _index = _bind$7._0;
          const _consumed = _bind$7._1;
          index = _index;
          consumed = _consumed;
          break _L;
        }
        off.val = off.val + consumed | 0;
        if (index === 0) {
          return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed("indexed header field with index 0"));
        }
        let header;
        _L$2: {
          const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack6lookup(self.table, index);
          if (_bind$6 === undefined) {
            return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error49moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eIndex(index));
          } else {
            const _Some = _bind$6;
            const _header = _Some;
            header = _header;
            break _L$2;
          }
        }
        keep(header);
      } else {
        if ((b & 64) !== 0) {
          let index;
          let consumed;
          _L: {
            const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack5reach(block, off.val, 6);
            let _bind$7;
            if (_bind$6.$tag === 1) {
              const _ok = _bind$6;
              _bind$7 = _ok._0;
            } else {
              return _bind$6;
            }
            const _index = _bind$7._0;
            const _consumed = _bind$7._1;
            index = _index;
            consumed = _consumed;
            break _L;
          }
          off.val = off.val + consumed | 0;
          let name;
          let name_consumed;
          _L$2: {
            const _bind$6 = _M0MP312moonbitstack8moonhttp5hpack7Decoder10read__name(self, block, index, off.val);
            let _bind$7;
            if (_bind$6.$tag === 1) {
              const _ok = _bind$6;
              _bind$7 = _ok._0;
            } else {
              return _bind$6;
            }
            const _name = _bind$7._0;
            const _name_consumed = _bind$7._1;
            name = _name;
            name_consumed = _name_consumed;
            break _L$2;
          }
          off.val = off.val + name_consumed | 0;
          let value;
          let value_consumed;
          _L$3: {
            const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack12read__string(block, off.val);
            let _bind$7;
            if (_bind$6.$tag === 1) {
              const _ok = _bind$6;
              _bind$7 = _ok._0;
            } else {
              return _bind$6;
            }
            const _value = _bind$7._0;
            const _value_consumed = _bind$7._1;
            value = _value;
            value_consumed = _value_consumed;
            break _L$3;
          }
          off.val = off.val + value_consumed | 0;
          _M0MP312moonbitstack8moonhttp5hpack5Table3add(self.table, name, value);
          keep(new _M0TP312moonbitstack8moonhttp6header6Header(name, value));
        } else {
          if ((b & 32) !== 0) {
            if (size.val > 0) {
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed("a dynamic table size update after a field"));
            }
            let wanted;
            let consumed;
            _L: {
              const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack5reach(block, off.val, 5);
              let _bind$7;
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _bind$7 = _ok._0;
              } else {
                return _bind$6;
              }
              const _wanted = _bind$7._0;
              const _consumed = _bind$7._1;
              wanted = _wanted;
              consumed = _consumed;
              break _L;
            }
            off.val = off.val + consumed | 0;
            if (wanted > self.limit) {
              const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(49);
              _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "a dynamic table size update to ");
              _M0MPB13StringBuilder13write__objectGiE(_string_builder, wanted);
              _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", past the agreed ");
              _M0MPB13StringBuilder13write__objectGiE(_string_builder, self.limit);
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eMalformed(_M0MPB13StringBuilder10to__string(_string_builder)));
            }
            _M0MP312moonbitstack8moonhttp5hpack5Table6resize(self.table, wanted);
          } else {
            let index;
            let consumed;
            _L: {
              const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack5reach(block, off.val, 4);
              let _bind$7;
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _bind$7 = _ok._0;
              } else {
                return _bind$6;
              }
              const _index = _bind$7._0;
              const _consumed = _bind$7._1;
              index = _index;
              consumed = _consumed;
              break _L;
            }
            off.val = off.val + consumed | 0;
            let name;
            let name_consumed;
            _L$2: {
              const _bind$6 = _M0MP312moonbitstack8moonhttp5hpack7Decoder10read__name(self, block, index, off.val);
              let _bind$7;
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _bind$7 = _ok._0;
              } else {
                return _bind$6;
              }
              const _name = _bind$7._0;
              const _name_consumed = _bind$7._1;
              name = _name;
              name_consumed = _name_consumed;
              break _L$2;
            }
            off.val = off.val + name_consumed | 0;
            let value;
            let value_consumed;
            _L$3: {
              const _bind$6 = _M0FP312moonbitstack8moonhttp5hpack12read__string(block, off.val);
              let _bind$7;
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _bind$7 = _ok._0;
              } else {
                return _bind$6;
              }
              const _value = _bind$7._0;
              const _value_consumed = _bind$7._1;
              value = _value;
              value_consumed = _value_consumed;
              break _L$3;
            }
            off.val = off.val + value_consumed | 0;
            keep(new _M0TP312moonbitstack8moonhttp6header6Header(name, value));
          }
        }
      }
      continue;
    } else {
      break;
    }
  }
  _L: {
    let l;
    _L$2: {
      if (limit === undefined) {
        break _L;
      } else {
        const _Some = limit;
        const _l = _Some;
        if (size.val > _l) {
          l = _l;
          break _L$2;
        } else {
          break _L;
        }
      }
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE3Err(new _M0DTPC15error5Error52moonbitstack_2fmoonhttp_2fhpack_2eRefused_2eExceeded(l, size.val));
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderERP312moonbitstack8moonhttp5hpack7RefusedE2Ok(out$2);
}
function _M0MP312moonbitstack8moonhttp5hpack7Encoder11new_2einner(limit, huffman) {
  return new _M0TP312moonbitstack8moonhttp5hpack7Encoder(_M0MP312moonbitstack8moonhttp5hpack5Table11new_2einner(limit), huffman);
}
function _M0MP312moonbitstack8moonhttp5hpack7Encoder3new(limit$46$opt, huffman$46$opt) {
  let limit;
  if (limit$46$opt === undefined) {
    limit = _M0FP312moonbitstack8moonhttp5hpack5limit;
  } else {
    const _Some = limit$46$opt;
    limit = _Some;
  }
  const huffman = huffman$46$opt === -1 ? true : huffman$46$opt;
  return _M0MP312moonbitstack8moonhttp5hpack7Encoder11new_2einner(limit, huffman);
}
function _M0MP312moonbitstack8moonhttp5hpack7Encoder4find(self, name, value) {
  const fixed = _M0FP312moonbitstack8moonhttp5hpack13static__table.length;
  const name_idx = new _M0TPB8MutLocalGiE(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < fixed) {
      const e = _M0MPC15array5Array2atGsE(_M0FP312moonbitstack8moonhttp5hpack13static__table, i);
      const n = e.name;
      const v = e.value;
      if ($bytes_equal(n, name)) {
        if ($bytes_equal(v, value)) {
          return { _0: i + 1 | 0, _1: true };
        }
        if (name_idx.val === 0) {
          name_idx.val = i + 1 | 0;
        }
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let _tmp$5 = 0;
  while (true) {
    const d = _tmp$5;
    if (d < self.table.entries.length) {
      let n;
      let v;
      _L: {
        const _bind$6 = _M0MPC15array5Array2atGsE(self.table.entries, d);
        const _n = _bind$6._0;
        const _v = _bind$6._1;
        n = _n;
        v = _v;
        break _L;
      }
      if ($bytes_equal(n, name)) {
        const idx = (fixed + 1 | 0) + d | 0;
        if ($bytes_equal(v, value)) {
          return { _0: idx, _1: true };
        }
        if (name_idx.val === 0) {
          name_idx.val = idx;
        }
      }
      _tmp$5 = d + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return { _0: name_idx.val, _1: false };
}
function _M0MP312moonbitstack8moonhttp5hpack7Encoder7literal(self, octets) {
  return _M0FP312moonbitstack8moonhttp5hpack14string_2einner(new _M0TPC15bytes9BytesView(octets, 0, octets.length), self.huffman);
}
function _M0MP312moonbitstack8moonhttp5hpack7Encoder6encode(self, headers) {
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  const _bind$6 = headers.end - headers.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const h = headers.buf[headers.start + _ | 0];
      let idx;
      let exact;
      _L: {
        const _bind$7 = _M0MP312moonbitstack8moonhttp5hpack7Encoder4find(self, h.name, h.value);
        const _idx = _bind$7._0;
        const _exact = _bind$7._1;
        idx = _idx;
        exact = _exact;
        break _L;
      }
      if (exact) {
        const _bind$7 = _M0FP312moonbitstack7moonvar6prefix14encode_2einner(idx, 7, 128);
        _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length));
      } else {
        if (idx !== 0) {
          const _bind$7 = _M0FP312moonbitstack7moonvar6prefix14encode_2einner(idx, 6, 64);
          _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length));
        } else {
          _M0MPC16buffer6Buffer11write__byte(buf, 64);
          const _bind$7 = _M0MP312moonbitstack8moonhttp5hpack7Encoder7literal(self, h.name);
          _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length));
        }
        const _bind$7 = _M0MP312moonbitstack8moonhttp5hpack7Encoder7literal(self, h.value);
        _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length));
        _M0MP312moonbitstack8moonhttp5hpack5Table3add(self.table, h.name, h.value);
      }
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP312moonbitstack7moonvar5fixed4fits(b, at, size) {
  return at >= 0 && (size >= 0 && at <= (_M0MPC15bytes9BytesView6length(b) - size | 0));
}
function _M0FP312moonbitstack7moonvar5fixed17read__u32_2einner(b, at, order) {
  if (!_M0FP312moonbitstack7moonvar5fixed4fits(b, at, 4)) {
    return undefined;
  }
  const out$2 = new _M0TPB8MutLocalGjE(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < 4) {
      let byte;
      if (order === 0) {
        byte = _M0MPC15bytes9BytesView2at(b, at + i | 0);
      } else {
        byte = _M0MPC15bytes9BytesView2at(b, (at + 3 | 0) - i | 0);
      }
      out$2.val = out$2.val << 8 | byte;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return out$2.val;
}
function _M0FP312moonbitstack7moonvar5fixed9read__u32(b, at$46$opt, order$46$opt) {
  let at;
  if (at$46$opt === undefined) {
    at = 0;
  } else {
    const _Some = at$46$opt;
    at = _Some;
  }
  let order;
  if (order$46$opt === undefined) {
    order = _M0FP312moonbitstack7moonvar5fixed5order;
  } else {
    const _Some = order$46$opt;
    order = _Some;
  }
  return _M0FP312moonbitstack7moonvar5fixed17read__u32_2einner(b, at, order);
}
function _M0FP312moonbitstack7moonvar5fixed17read__u64_2einner(b, at, order) {
  if (!_M0FP312moonbitstack7moonvar5fixed4fits(b, at, 8)) {
    return undefined;
  }
  const out$2 = new _M0TPB8MutLocalGmE(0n);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < 8) {
      let byte;
      if (order === 0) {
        byte = _M0MPC15bytes9BytesView2at(b, at + i | 0);
      } else {
        byte = _M0MPC15bytes9BytesView2at(b, (at + 7 | 0) - i | 0);
      }
      out$2.val = BigInt.asUintN(64, BigInt.asUintN(64, out$2.val << BigInt(8 & 63)) | BigInt.asUintN(64, BigInt(byte)));
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return out$2.val;
}
function _M0FP312moonbitstack7moonvar5fixed18write__u16_2einner(buf, v, order) {
  if (order === 0) {
    _M0MPC16buffer6Buffer11write__byte(buf, v >> 8 & 255);
    _M0MPC16buffer6Buffer11write__byte(buf, v & 255);
    return;
  } else {
    _M0MPC16buffer6Buffer11write__byte(buf, v & 255);
    _M0MPC16buffer6Buffer11write__byte(buf, v >> 8 & 255);
    return;
  }
}
function _M0FP312moonbitstack7moonvar5fixed10write__u16(buf, v, order$46$opt) {
  let order;
  if (order$46$opt === undefined) {
    order = _M0FP312moonbitstack7moonvar5fixed5order;
  } else {
    const _Some = order$46$opt;
    order = _Some;
  }
  _M0FP312moonbitstack7moonvar5fixed18write__u16_2einner(buf, v, order);
}
function _M0FP312moonbitstack7moonvar5fixed18write__u24_2einner(buf, v, order) {
  if (order === 0) {
    let _tmp$4 = 2;
    while (true) {
      const i = _tmp$4;
      if (i >= 0) {
        _M0MPC16buffer6Buffer11write__byte(buf, v >> (Math.imul(i, 8) | 0) & 255);
        _tmp$4 = i - 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp$4 = 0;
    while (true) {
      const i = _tmp$4;
      if (i < 3) {
        _M0MPC16buffer6Buffer11write__byte(buf, v >> (Math.imul(i, 8) | 0) & 255);
        _tmp$4 = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0FP312moonbitstack7moonvar5fixed10write__u24(buf, v, order$46$opt) {
  let order;
  if (order$46$opt === undefined) {
    order = _M0FP312moonbitstack7moonvar5fixed5order;
  } else {
    const _Some = order$46$opt;
    order = _Some;
  }
  _M0FP312moonbitstack7moonvar5fixed18write__u24_2einner(buf, v, order);
}
function _M0FP312moonbitstack7moonvar5fixed18write__u32_2einner(buf, v, order) {
  if (order === 0) {
    let _tmp$4 = 3;
    while (true) {
      const i = _tmp$4;
      if (i >= 0) {
        _M0MPC16buffer6Buffer11write__byte(buf, _M0MPC14uint4UInt8to__byte(v >>> (Math.imul(i, 8) | 0) | 0));
        _tmp$4 = i - 1 | 0;
        continue;
      } else {
        return;
      }
    }
  } else {
    let _tmp$4 = 0;
    while (true) {
      const i = _tmp$4;
      if (i < 4) {
        _M0MPC16buffer6Buffer11write__byte(buf, _M0MPC14uint4UInt8to__byte(v >>> (Math.imul(i, 8) | 0) | 0));
        _tmp$4 = i + 1 | 0;
        continue;
      } else {
        return;
      }
    }
  }
}
function _M0FP312moonbitstack7moonvar5fixed10write__u32(buf, v, order$46$opt) {
  let order;
  if (order$46$opt === undefined) {
    order = _M0FP312moonbitstack7moonvar5fixed5order;
  } else {
    const _Some = order$46$opt;
    order = _Some;
  }
  _M0FP312moonbitstack7moonvar5fixed18write__u32_2einner(buf, v, order);
}
function _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(buf, id, top_bit) {
  const top = top_bit ? -2147483648 : 0;
  _M0FP312moonbitstack7moonvar5fixed10write__u32(buf, id & 2147483647 | top, undefined);
}
function _M0FP312moonbitstack8moonhttp5http219be__write__priority(buf, p) {
  _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(buf, p.stream_dependency, p.exclusive);
  _M0MPC16buffer6Buffer11write__byte(buf, p.weight & 255);
}
function _M0FP312moonbitstack8moonhttp5http214be__write__u16(buf, n) {
  _M0FP312moonbitstack7moonvar5fixed10write__u16(buf, n, undefined);
}
function _M0FP312moonbitstack8moonhttp5http214be__write__u32(buf, n) {
  _M0FP312moonbitstack7moonvar5fixed10write__u32(buf, n, undefined);
}
function _M0FP312moonbitstack8moonhttp5http214be__write__u24(buf, n) {
  _M0FP312moonbitstack7moonvar5fixed10write__u24(buf, n, undefined);
}
function _M0FP312moonbitstack8moonhttp5http24emit(ftype, flags, stream_id, payload) {
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  _M0FP312moonbitstack8moonhttp5http214be__write__u24(buf, payload.length);
  _M0MPC16buffer6Buffer11write__byte(buf, ftype & 255);
  _M0MPC16buffer6Buffer11write__byte(buf, flags & 255);
  _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(buf, stream_id, false);
  _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(payload, 0, payload.length));
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP312moonbitstack8moonhttp5http214write__padding(buf, n) {
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < n) {
      _M0MPC16buffer6Buffer11write__byte(buf, 0);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      return;
    }
  }
}
function _M0MP312moonbitstack8moonhttp5http25Frame6encode(self) {
  let stream_id;
  let ftype;
  let flags;
  let payload;
  _L: {
    let fragment;
    let stream_id$2;
    let end_headers;
    _L$2: {
      let stream_id$3;
      let increment;
      _L$3: {
        let error_code;
        let last_stream_id;
        let debug;
        _L$4: {
          let payload$2;
          let ack;
          _L$5: {
            let end_headers$2;
            let promised_id;
            let stream_id$4;
            let fragment$2;
            let padding;
            _L$6: {
              let params;
              let ack$2;
              _L$7: {
                let stream_id$5;
                let error_code$2;
                _L$8: {
                  let stream_id$6;
                  let priority;
                  _L$9: {
                    let priority$2;
                    let end_stream;
                    let stream_id$7;
                    let fragment$3;
                    let end_headers$3;
                    let padding$2;
                    _L$10: {
                      let end_stream$2;
                      let stream_id$8;
                      let data;
                      let padding$3;
                      _L$11: {
                        switch (self.$tag) {
                          case 0: {
                            const _Data = self;
                            const _stream_id = _Data._0;
                            const _data = _Data._1;
                            const _end_stream = _Data._2;
                            const _padding = _Data._3;
                            end_stream$2 = _end_stream;
                            stream_id$8 = _stream_id;
                            data = _data;
                            padding$3 = _padding;
                            break _L$11;
                          }
                          case 1: {
                            const _Headers = self;
                            const _stream_id$2 = _Headers._0;
                            const _fragment = _Headers._1;
                            const _end_stream$2 = _Headers._2;
                            const _end_headers = _Headers._3;
                            const _priority = _Headers._4;
                            const _padding$2 = _Headers._5;
                            priority$2 = _priority;
                            end_stream = _end_stream$2;
                            stream_id$7 = _stream_id$2;
                            fragment$3 = _fragment;
                            end_headers$3 = _end_headers;
                            padding$2 = _padding$2;
                            break _L$10;
                          }
                          case 2: {
                            const _Priority = self;
                            const _stream_id$3 = _Priority._0;
                            const _priority$2 = _Priority._1;
                            stream_id$6 = _stream_id$3;
                            priority = _priority$2;
                            break _L$9;
                          }
                          case 3: {
                            const _RstStream = self;
                            const _stream_id$4 = _RstStream._0;
                            const _error_code = _RstStream._1;
                            stream_id$5 = _stream_id$4;
                            error_code$2 = _error_code;
                            break _L$8;
                          }
                          case 4: {
                            const _Settings = self;
                            const _params = _Settings._0;
                            const _ack = _Settings._1;
                            params = _params;
                            ack$2 = _ack;
                            break _L$7;
                          }
                          case 5: {
                            const _PushPromise = self;
                            const _stream_id$5 = _PushPromise._0;
                            const _promised_id = _PushPromise._1;
                            const _fragment$2 = _PushPromise._2;
                            const _end_headers$2 = _PushPromise._3;
                            const _padding$3 = _PushPromise._4;
                            end_headers$2 = _end_headers$2;
                            promised_id = _promised_id;
                            stream_id$4 = _stream_id$5;
                            fragment$2 = _fragment$2;
                            padding = _padding$3;
                            break _L$6;
                          }
                          case 6: {
                            const _Ping = self;
                            const _payload = _Ping._0;
                            const _ack$2 = _Ping._1;
                            payload$2 = _payload;
                            ack = _ack$2;
                            break _L$5;
                          }
                          case 7: {
                            const _GoAway = self;
                            const _last_stream_id = _GoAway._0;
                            const _error_code$2 = _GoAway._1;
                            const _debug = _GoAway._2;
                            error_code = _error_code$2;
                            last_stream_id = _last_stream_id;
                            debug = _debug;
                            break _L$4;
                          }
                          case 8: {
                            const _WindowUpdate = self;
                            const _stream_id$6 = _WindowUpdate._0;
                            const _increment = _WindowUpdate._1;
                            stream_id$3 = _stream_id$6;
                            increment = _increment;
                            break _L$3;
                          }
                          case 9: {
                            const _Continuation = self;
                            const _stream_id$7 = _Continuation._0;
                            const _fragment$3 = _Continuation._1;
                            const _end_headers$3 = _Continuation._2;
                            fragment = _fragment$3;
                            stream_id$2 = _stream_id$7;
                            end_headers = _end_headers$3;
                            break _L$2;
                          }
                          default: {
                            const _Unknown = self;
                            const _ftype = _Unknown._0;
                            const _flags = _Unknown._1;
                            const _stream_id$8 = _Unknown._2;
                            const _payload$2 = _Unknown._3;
                            stream_id = _stream_id$8;
                            ftype = _ftype;
                            flags = _flags;
                            payload = _payload$2;
                            break _L;
                          }
                        }
                      }
                      const flags$2 = new _M0TPB8MutLocalGiE(0);
                      if (end_stream$2) {
                        flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http217flag__end__stream;
                      }
                      const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
                      if (padding$3 > 0) {
                        flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http212flag__padded;
                        _M0MPC16buffer6Buffer11write__byte(body, padding$3 & 255);
                      }
                      _M0MPC16buffer6Buffer12write__bytes(body, new _M0TPC15bytes9BytesView(data, 0, data.length));
                      _M0FP312moonbitstack8moonhttp5http214write__padding(body, padding$3);
                      return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http211frame__data, flags$2.val, stream_id$8, _M0MPC16buffer6Buffer9to__bytes(body));
                    }
                    const flags$2 = new _M0TPB8MutLocalGiE(0);
                    if (end_stream) {
                      flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http217flag__end__stream;
                    }
                    if (end_headers$3) {
                      flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http218flag__end__headers;
                    }
                    const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
                    if (padding$2 > 0) {
                      flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http212flag__padded;
                      _M0MPC16buffer6Buffer11write__byte(body, padding$2 & 255);
                    }
                    let p;
                    _L$11: {
                      _L$12: {
                        if (priority$2 === undefined) {
                        } else {
                          const _Some = priority$2;
                          const _p = _Some;
                          p = _p;
                          break _L$12;
                        }
                        break _L$11;
                      }
                      flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http214flag__priority;
                      _M0FP312moonbitstack8moonhttp5http219be__write__priority(body, p);
                    }
                    _M0MPC16buffer6Buffer12write__bytes(body, new _M0TPC15bytes9BytesView(fragment$3, 0, fragment$3.length));
                    _M0FP312moonbitstack8moonhttp5http214write__padding(body, padding$2);
                    return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http214frame__headers, flags$2.val, stream_id$7, _M0MPC16buffer6Buffer9to__bytes(body));
                  }
                  const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
                  _M0FP312moonbitstack8moonhttp5http219be__write__priority(body, priority);
                  return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http215frame__priority, 0, stream_id$6, _M0MPC16buffer6Buffer9to__bytes(body));
                }
                const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
                _M0FP312moonbitstack8moonhttp5http214be__write__u32(body, error_code$2);
                return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http218frame__rst__stream, 0, stream_id$5, _M0MPC16buffer6Buffer9to__bytes(body));
              }
              const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
              if (!ack$2) {
                const _bind$6 = params.length;
                let _tmp$4 = 0;
                while (true) {
                  const _ = _tmp$4;
                  if (_ < _bind$6) {
                    const pair = params[_];
                    _M0FP312moonbitstack8moonhttp5http214be__write__u16(body, pair._0);
                    _M0FP312moonbitstack8moonhttp5http214be__write__u32(body, pair._1);
                    _tmp$4 = _ + 1 | 0;
                    continue;
                  } else {
                    break;
                  }
                }
              }
              return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http215frame__settings, ack$2 ? _M0FP312moonbitstack8moonhttp5http29flag__ack : 0, 0, _M0MPC16buffer6Buffer9to__bytes(body));
            }
            const flags$2 = new _M0TPB8MutLocalGiE(0);
            if (end_headers$2) {
              flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http218flag__end__headers;
            }
            const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
            if (padding > 0) {
              flags$2.val = flags$2.val | _M0FP312moonbitstack8moonhttp5http212flag__padded;
              _M0MPC16buffer6Buffer11write__byte(body, padding & 255);
            }
            _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(body, promised_id, false);
            _M0MPC16buffer6Buffer12write__bytes(body, new _M0TPC15bytes9BytesView(fragment$2, 0, fragment$2.length));
            _M0FP312moonbitstack8moonhttp5http214write__padding(body, padding);
            return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http220frame__push__promise, flags$2.val, stream_id$4, _M0MPC16buffer6Buffer9to__bytes(body));
          }
          return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http211frame__ping, ack ? _M0FP312moonbitstack8moonhttp5http29flag__ack : 0, 0, payload$2);
        }
        const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
        _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(body, last_stream_id, false);
        _M0FP312moonbitstack8moonhttp5http214be__write__u32(body, error_code);
        _M0MPC16buffer6Buffer12write__bytes(body, new _M0TPC15bytes9BytesView(debug, 0, debug.length));
        return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http213frame__goaway, 0, 0, _M0MPC16buffer6Buffer9to__bytes(body));
      }
      const body = _M0MPC16buffer6Buffer14Buffer_2einner(0);
      _M0FP312moonbitstack8moonhttp5http221be__write__stream__id(body, increment, false);
      return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http221frame__window__update, 0, stream_id$3, _M0MPC16buffer6Buffer9to__bytes(body));
    }
    return _M0FP312moonbitstack8moonhttp5http24emit(_M0FP312moonbitstack8moonhttp5http219frame__continuation, end_headers ? _M0FP312moonbitstack8moonhttp5http218flag__end__headers : 0, stream_id$2, fragment);
  }
  return _M0FP312moonbitstack8moonhttp5http24emit(ftype, flags, stream_id, payload);
}
function _M0MP312moonbitstack8moonhttp5http25Frame4code(self) {
  switch (self.$tag) {
    case 0: {
      return _M0FP312moonbitstack8moonhttp5http211frame__data;
    }
    case 1: {
      return _M0FP312moonbitstack8moonhttp5http214frame__headers;
    }
    case 2: {
      return _M0FP312moonbitstack8moonhttp5http215frame__priority;
    }
    case 3: {
      return _M0FP312moonbitstack8moonhttp5http218frame__rst__stream;
    }
    case 4: {
      return _M0FP312moonbitstack8moonhttp5http215frame__settings;
    }
    case 5: {
      return _M0FP312moonbitstack8moonhttp5http220frame__push__promise;
    }
    case 6: {
      return _M0FP312moonbitstack8moonhttp5http211frame__ping;
    }
    case 7: {
      return _M0FP312moonbitstack8moonhttp5http213frame__goaway;
    }
    case 8: {
      return _M0FP312moonbitstack8moonhttp5http221frame__window__update;
    }
    case 9: {
      return _M0FP312moonbitstack8moonhttp5http219frame__continuation;
    }
    default: {
      const _Unknown = self;
      const _ftype = _Unknown._0;
      return _ftype;
    }
  }
}
function _M0FP212moonbitstack8moonbase8text__of(input) {
  const out$2 = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  const _bind$6 = 0;
  const _bind$7 = _M0MPC15bytes9BytesView6length(input);
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      _M0IPB13StringBuilderPB6Logger11write__char(out$2, _M0MPC15bytes9BytesView2at(input, i));
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPB13StringBuilder10to__string(out$2);
}
function _M0FP212moonbitstack8moonbase9group__of(bits) {
  const chars = new _M0TPB8MutLocalGiE(1);
  while (true) {
    if (8 === 0) {
      $panic();
    }
    if (((Math.imul(chars.val, bits) | 0) % 8 | 0) !== 0) {
      chars.val = chars.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return chars.val;
}
function _M0FP212moonbitstack8moonbase4pack(input, bits, digits, pad) {
  const out$2 = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  const buffer = new _M0TPB8MutLocalGiE(0);
  const held = new _M0TPB8MutLocalGiE(0);
  const mask = (1 << bits) - 1 | 0;
  const count = new _M0TPB8MutLocalGiE(0);
  const _bind$6 = 0;
  const _bind$7 = _M0MPC15bytes9BytesView6length(input);
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      buffer.val = buffer.val << 8 | _M0MPC15bytes9BytesView2at(input, i);
      held.val = held.val + 8 | 0;
      while (true) {
        if (held.val >= bits) {
          held.val = held.val - bits | 0;
          _M0IPB13StringBuilderPB6Logger11write__char(out$2, _M0MPC15array5Array2atGcE(digits, buffer.val >> held.val & mask));
          count.val = count.val + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      buffer.val = buffer.val & ((1 << held.val) - 1 | 0);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (held.val > 0) {
    _M0IPB13StringBuilderPB6Logger11write__char(out$2, _M0MPC15array5Array2atGcE(digits, buffer.val << (bits - held.val | 0) & mask));
    count.val = count.val + 1 | 0;
  }
  if (pad) {
    const group = _M0FP212moonbitstack8moonbase9group__of(bits);
    while (true) {
      if (group === 0) {
        $panic();
      }
      if ((count.val % group | 0) !== 0) {
        _M0IPB13StringBuilderPB6Logger11write__char(out$2, 61);
        count.val = count.val + 1 | 0;
        continue;
      } else {
        break;
      }
    }
  }
  return _M0MPB13StringBuilder10to__string(out$2);
}
function _M0FP212moonbitstack8moonbase11pack__bytes(input, bits, digits, pad) {
  const text = _M0FP212moonbitstack8moonbase4pack(input, bits, digits, pad);
  const out$2 = _M0MPC15array5Array4makeGyE(text.length, 0);
  const _bind$6 = 0;
  const _bind$7 = text.length;
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      _M0MPC15array5Array3setGyE(out$2, i, (i >>> 0 < text.length ? text.charCodeAt(i) : $oob()) & 255);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(out$2, 0, out$2.length));
}
function _M0FP212moonbitstack8moonbase6unpack(input, bits, lookup, lossy) {
  const out$2 = [];
  const buffer = new _M0TPB8MutLocalGiE(0);
  const held = new _M0TPB8MutLocalGiE(0);
  const taken = new _M0TPB8MutLocalGiE(0);
  const padding = new _M0TPB8MutLocalGbE(false);
  const _bind$6 = 0;
  const _bind$7 = _M0MPC16string10StringView6length(input);
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      _L: {
        const code = _M0MPC16string10StringView2at(input, i);
        if (code === 61) {
          padding.val = true;
          break _L;
        }
        if (padding.val && !lossy) {
          return new _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE3Err(new _M0DTPC15error5Error45moonbitstack_2fmoonbase_2eMalformed_2ePadding(i));
        }
        const value = code >= 0 && code < 128 ? _M0MPC15array5Array2atGiE(lookup, code) : -1;
        if (value < 0) {
          if (lossy) {
            break _L;
          }
          return new _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE3Err(new _M0DTPC15error5Error41moonbitstack_2fmoonbase_2eMalformed_2eBad(i, code));
        }
        buffer.val = buffer.val << bits | value;
        held.val = held.val + bits | 0;
        taken.val = taken.val + 1 | 0;
        while (true) {
          if (held.val >= 8) {
            held.val = held.val - 8 | 0;
            _M0MPC15array5Array4pushGyE(out$2, buffer.val >> held.val & 255);
            continue;
          } else {
            break;
          }
        }
        buffer.val = buffer.val & ((1 << held.val) - 1 | 0);
        break _L;
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (8 === 0) {
    $panic();
  }
  if (((Math.imul(taken.val, bits) | 0) % 8 | 0) >= bits) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE3Err(new _M0DTPC15error5Error47moonbitstack_2fmoonbase_2eMalformed_2eTruncated(_M0MPC16string10StringView6length(input)));
  }
  return new _M0DTPC16result6ResultGzRP212moonbitstack8moonbase9MalformedE2Ok(_M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(out$2, 0, out$2.length)));
}
function _M0FP212moonbitstack8moonbase10lookup__of(chars) {
  const table = _M0MPC15array5Array4makeGiE(128, -1);
  const digits = _M0MPC16string6String9to__array(chars);
  const _bind$6 = 0;
  const _bind$7 = digits.length;
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      const code = _M0MPC15array5Array2atGcE(digits, i);
      if (code >= 0 && code < 128) {
        _M0MPC15array5Array3setGiE(table, code, i);
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return table;
}
function _M0FP312moonbitstack8moonbase6base646digits(kind) {
  if (kind === 0) {
    return _M0FP312moonbitstack8moonbase6base6411std__digits;
  } else {
    return _M0FP312moonbitstack8moonbase6base6411url__digits;
  }
}
function _M0FP312moonbitstack8moonbase6base6421encode__bytes_2einner(input, kind, padding) {
  return _M0FP212moonbitstack8moonbase11pack__bytes(input, 6, _M0FP312moonbitstack8moonbase6base646digits(kind), padding);
}
function _M0FP312moonbitstack8moonbase6base6413encode__bytes(input, kind$46$opt, padding$46$opt) {
  let kind;
  if (kind$46$opt === undefined) {
    kind = 0;
  } else {
    const _Some = kind$46$opt;
    kind = _Some;
  }
  const padding = padding$46$opt === -1 ? true : padding$46$opt;
  return _M0FP312moonbitstack8moonbase6base6421encode__bytes_2einner(input, kind, padding);
}
function _M0FP312moonbitstack8moonbase6base646lookup(kind) {
  if (kind === 0) {
    return _M0FP312moonbitstack8moonbase6base6411std__lookup;
  } else {
    return _M0FP312moonbitstack8moonbase6base6411url__lookup;
  }
}
function _M0FP312moonbitstack8moonbase6base6421decode__lossy_2einner(input, kind) {
  let _try_err;
  _L: {
    const _bind$6 = _M0FP212moonbitstack8moonbase6unpack(input, 6, _M0FP312moonbitstack8moonbase6base646lookup(kind), true);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      return _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
  }
  return $bytes_literal$0;
}
function _M0FP312moonbitstack8moonbase6base6413decode__lossy(input, kind$46$opt) {
  let kind;
  if (kind$46$opt === undefined) {
    kind = 0;
  } else {
    const _Some = kind$46$opt;
    kind = _Some;
  }
  return _M0FP312moonbitstack8moonbase6base6421decode__lossy_2einner(input, kind);
}
function _M0MP312moonbitstack7moonrpc4wire6Status4name(self) {
  switch (self) {
    case 0: {
      return "OK";
    }
    case 1: {
      return "CANCELLED";
    }
    case 2: {
      return "UNKNOWN";
    }
    case 3: {
      return "INVALID_ARGUMENT";
    }
    case 4: {
      return "DEADLINE_EXCEEDED";
    }
    case 5: {
      return "NOT_FOUND";
    }
    case 6: {
      return "ALREADY_EXISTS";
    }
    case 7: {
      return "PERMISSION_DENIED";
    }
    case 8: {
      return "RESOURCE_EXHAUSTED";
    }
    case 9: {
      return "FAILED_PRECONDITION";
    }
    case 10: {
      return "ABORTED";
    }
    case 11: {
      return "OUT_OF_RANGE";
    }
    case 12: {
      return "UNIMPLEMENTED";
    }
    case 13: {
      return "INTERNAL";
    }
    case 14: {
      return "UNAVAILABLE";
    }
    case 15: {
      return "DATA_LOSS";
    }
    default: {
      return "UNAUTHENTICATED";
    }
  }
}
function _M0IP312moonbitstack7moonrpc4wire11StatusErrorPB4Show6output(self, logger) {
  let status;
  let message;
  _L: {
    const _StatusError = self;
    const _status = _StatusError._0;
    const _message = _StatusError._1;
    status = _status;
    message = _message;
    break _L;
  }
  logger.method_table.method_0(logger.self, `${_M0MP312moonbitstack7moonrpc4wire6Status4name(status)}: ${message}`);
}
function _M0FP312moonbitstack7moonrpc4wire23encode__message_2einner(payload, compressed) {
  const n = payload.length;
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  _M0MPC16buffer6Buffer11write__byte(buf, (compressed ? 1 : 0) & 255);
  _M0FP312moonbitstack7moonvar5fixed10write__u32(buf, n, undefined);
  _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(payload, 0, payload.length));
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP312moonbitstack7moonrpc4wire20message__len_2einner(data, at) {
  return _M0MPC16option6Option3mapGjiE(_M0FP312moonbitstack7moonvar5fixed9read__u32(data, at + 1 | 0, undefined), (v) => v);
}
function _M0MP312moonbitstack7moonrpc4wire6Status4code(self) {
  switch (self) {
    case 0: {
      return 0;
    }
    case 1: {
      return 1;
    }
    case 2: {
      return 2;
    }
    case 3: {
      return 3;
    }
    case 4: {
      return 4;
    }
    case 5: {
      return 5;
    }
    case 6: {
      return 6;
    }
    case 7: {
      return 7;
    }
    case 8: {
      return 8;
    }
    case 9: {
      return 9;
    }
    case 10: {
      return 10;
    }
    case 11: {
      return 11;
    }
    case 12: {
      return 12;
    }
    case 13: {
      return 13;
    }
    case 14: {
      return 14;
    }
    case 15: {
      return 15;
    }
    default: {
      return 16;
    }
  }
}
function _M0MP312moonbitstack7moonrpc4wire6Status15from__h2__error(code) {
  return code === _M0FP312moonbitstack8moonhttp5http222error__refused__stream ? 14 : code === _M0FP312moonbitstack8moonhttp5http226error__enhance__your__calm ? 8 : code === _M0FP312moonbitstack8moonhttp5http227error__inadequate__security ? 7 : code === _M0FP312moonbitstack8moonhttp5http213error__cancel ? 1 : 13;
}
function _M0MP312moonbitstack7moonrpc4wire6Status10from__http(code) {
  _L: {
    switch (code) {
      case 400: {
        return 13;
      }
      case 401: {
        return 16;
      }
      case 403: {
        return 7;
      }
      case 404: {
        return 12;
      }
      case 429: {
        break _L;
      }
      case 502: {
        break _L;
      }
      case 503: {
        break _L;
      }
      case 504: {
        break _L;
      }
      default: {
        return 2;
      }
    }
  }
  return 14;
}
function _M0FP312moonbitstack7moonrpc4wire20is__binary__metadata(name) {
  const n = name.length;
  if (n >= 4) {
    let _tmp$4;
    const _tmp$5 = n - 4 | 0;
    if (_M0IPC14byte4BytePB2Eq5equal(_tmp$5 >>> 0 < name.length ? name[_tmp$5] : $oob(), 45)) {
      let _tmp$6;
      const _tmp$7 = n - 3 | 0;
      if (_M0IPC14byte4BytePB2Eq5equal(_tmp$7 >>> 0 < name.length ? name[_tmp$7] : $oob(), 98)) {
        let _tmp$8;
        const _tmp$9 = n - 2 | 0;
        if (_M0IPC14byte4BytePB2Eq5equal(_tmp$9 >>> 0 < name.length ? name[_tmp$9] : $oob(), 105)) {
          const _tmp$10 = n - 1 | 0;
          _tmp$8 = _M0IPC14byte4BytePB2Eq5equal(_tmp$10 >>> 0 < name.length ? name[_tmp$10] : $oob(), 110);
        } else {
          _tmp$8 = false;
        }
        _tmp$6 = _tmp$8;
      } else {
        _tmp$6 = false;
      }
      _tmp$4 = _tmp$6;
    } else {
      _tmp$4 = false;
    }
    return _tmp$4;
  } else {
    return false;
  }
}
function _M0FP312moonbitstack7moonrpc4wire27metadata__value__from__wire(name, value) {
  if (_M0FP312moonbitstack7moonrpc4wire20is__binary__metadata(name)) {
    const _bind$6 = _M0FP212moonbitstack8moonbase8text__of(new _M0TPC15bytes9BytesView(value, 0, value.length));
    return _M0FP312moonbitstack8moonbase6base6413decode__lossy(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), undefined);
  } else {
    return value;
  }
}
function _M0FP312moonbitstack7moonrpc4wire25metadata__value__to__wire(name, value) {
  return _M0FP312moonbitstack7moonrpc4wire20is__binary__metadata(name) ? _M0FP312moonbitstack8moonbase6base6413encode__bytes(new _M0TPC15bytes9BytesView(value, 0, value.length), undefined, -1) : value;
}
function _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(buf) {
  if (_M0MPC16buffer6Buffer6length(buf) > _M0FP312moonbitstack7moonrpc4wire23max__header__list__size) {
    return new _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http225error__frame__size__error, `field block over ${_M0MPC13int3Int18to__string_2einner(_M0FP312moonbitstack7moonrpc4wire23max__header__list__size, 10)} octets`));
  } else {
    return new _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(undefined);
  }
}
function _M0FP412moonbitstack7moonrpc8internal2h220is__reserved__header(name) {
  return name.length > 0 && _M0IPC14byte4BytePB2Eq5equal(0 >>> 0 < name.length ? name[0] : $oob(), 58) || ($bytes_equal(name, $bytes_literal$1) || ($bytes_equal(name, $bytes_literal$2) || ($bytes_equal(name, $bytes_literal$3) || ($bytes_equal(name, $bytes_literal$4) || ($bytes_equal(name, $bytes_literal$5) || $bytes_equal(name, $bytes_literal$6))))));
}
function _M0FP412moonbitstack7moonrpc8internal2h211add__window(cur, inc) {
  const sum = BigInt.asUintN(64, BigInt.asUintN(64, BigInt(cur)) + BigInt.asUintN(64, BigInt(inc)));
  return BigInt.asIntN(64, sum) > BigInt.asIntN(64, 2147483647n) ? 2147483647 : BigInt.asIntN(64, sum) < BigInt.asIntN(64, 18446744071562067969n) ? -2147483647 : Number(BigInt.asIntN(32, sum)) | 0;
}
function _M0FP212moonbitstack7moonurl10gen__delim(b) {
  return b === 58 || (b === 47 || (b === 63 || (b === 35 || (b === 91 || (b === 93 || b === 64)))));
}
function _M0FP212moonbitstack7moonurl10sub__delim(b) {
  return b === 33 || (b === 36 || (b === 38 || (b === 39 || (b === 40 || (b === 41 || (b === 42 || (b === 43 || (b === 44 || (b === 59 || b === 61)))))))));
}
function _M0FP212moonbitstack7moonurl5alpha(b) {
  return b >= 65 && b <= 90 || b >= 97 && b <= 122;
}
function _M0FP212moonbitstack7moonurl5digit(b) {
  return b >= 48 && b <= 57;
}
function _M0FP212moonbitstack7moonurl10unreserved(b) {
  return _M0FP212moonbitstack7moonurl5alpha(b) || (_M0FP212moonbitstack7moonurl5digit(b) || (b === 45 || (b === 46 || (b === 95 || b === 126))));
}
function _M0FP212moonbitstack7moonurl7allowed(kind, b) {
  if (_M0FP212moonbitstack7moonurl10unreserved(b)) {
    return true;
  }
  _L: {
    switch (kind) {
      case 0: {
        return false;
      }
      case 1: {
        return _M0FP212moonbitstack7moonurl10sub__delim(b);
      }
      case 2: {
        return _M0FP212moonbitstack7moonurl10sub__delim(b) || b === 58;
      }
      case 3: {
        return _M0FP212moonbitstack7moonurl10sub__delim(b) || (b === 58 || b === 64);
      }
      case 4: {
        return _M0FP212moonbitstack7moonurl10sub__delim(b) || (b === 58 || (b === 64 || b === 47));
      }
      case 5: {
        break _L;
      }
      case 6: {
        break _L;
      }
      default: {
        return _M0FP212moonbitstack7moonurl10sub__delim(b) || (_M0FP212moonbitstack7moonurl10gen__delim(b) || b === 37);
      }
    }
  }
  return _M0FP212moonbitstack7moonurl10sub__delim(b) || (b === 58 || (b === 64 || (b === 47 || b === 63)));
}
function _M0FP212moonbitstack7moonurl6spared(spare, b) {
  if (b >= 128) {
    return false;
  }
  const _bind$6 = spare.str;
  const _bind$7 = spare.start;
  const _bind$8 = spare.end;
  let _tmp$4 = _bind$7;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$8) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$9 = _bind$6.charCodeAt(_string_index);
        if (_bind$9 >= 55296 && _bind$9 <= 56319 && (_string_index + 1 | 0) < _bind$8) {
          const _bind$10 = _bind$6.charCodeAt(_string_index + 1 | 0);
          if (_bind$10 >= 56320 && _bind$10 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$9 - 55296 | 0, 1024) | 0) + _bind$10 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$9);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$9);
          break _L;
        }
      }
      const _next_string_index = _decoded_next_string_index;
      const c = _decoded_char;
      if (c === b) {
        return true;
      }
      _tmp$4 = _next_string_index;
      continue;
    } else {
      break;
    }
  }
  return false;
}
function _M0FP212moonbitstack7moonurl14escape_2einner(raw, kind, spare) {
  const digits = "0123456789ABCDEF";
  const out$2 = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < _M0MPC15bytes9BytesView6length(raw)) {
      const b = _M0MPC15bytes9BytesView2at(raw, i);
      if (_M0FP212moonbitstack7moonurl7allowed(kind, b) || _M0FP212moonbitstack7moonurl6spared(spare, b)) {
        _M0IPB13StringBuilderPB6Logger11write__char(out$2, b);
      } else {
        _M0IPB13StringBuilderPB6Logger11write__char(out$2, 37);
        if (16 === 0) {
          $panic();
        }
        const _tmp$5 = b / 16 | 0;
        _M0IPB13StringBuilderPB6Logger11write__char(out$2, _M0MPC16uint166UInt1616unsafe__to__char(_tmp$5 >>> 0 < digits.length ? digits.charCodeAt(_tmp$5) : $oob()));
        if (16 === 0) {
          $panic();
        }
        const _tmp$6 = b % 16 | 0;
        _M0IPB13StringBuilderPB6Logger11write__char(out$2, _M0MPC16uint166UInt1616unsafe__to__char(_tmp$6 >>> 0 < digits.length ? digits.charCodeAt(_tmp$6) : $oob()));
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPB13StringBuilder10to__string(out$2);
}
function _M0FP212moonbitstack7moonurl20escape__text_2einner(text, kind, spare) {
  const _bind$6 = _M0FPC28encoding4utf814encode_2einner(text, false);
  return _M0FP212moonbitstack7moonurl14escape_2einner(new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), kind, spare);
}
function _M0FP212moonbitstack7moonurl12escape__text(text, kind$46$opt, spare$46$opt) {
  let kind;
  if (kind$46$opt === undefined) {
    kind = _M0FP212moonbitstack7moonurl4kind;
  } else {
    const _Some = kind$46$opt;
    kind = _Some;
  }
  let spare;
  if (spare$46$opt === undefined) {
    spare = new _M0TPC16string10StringView("", 0, 0);
  } else {
    const _Some = spare$46$opt;
    spare = _Some;
  }
  return _M0FP212moonbitstack7moonurl20escape__text_2einner(text, kind, spare);
}
function _M0FP212moonbitstack7moonurl6nibble(b) {
  const c = b;
  return c >= 48 && c <= 57 ? c - 48 | 0 : c >= 65 && c <= 70 ? c - 55 | 0 : c >= 97 && c <= 102 ? c - 87 | 0 : -1;
}
function _M0FP212moonbitstack7moonurl8unescape(raw) {
  const out$2 = [];
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < _M0MPC15bytes9BytesView6length(raw)) {
      if (_M0IPC14byte4BytePB2Eq5equal(_M0MPC15bytes9BytesView2at(raw, i.val), 37) && (i.val + 2 | 0) < _M0MPC15bytes9BytesView6length(raw)) {
        const hi = _M0FP212moonbitstack7moonurl6nibble(_M0MPC15bytes9BytesView2at(raw, i.val + 1 | 0));
        const lo = _M0FP212moonbitstack7moonurl6nibble(_M0MPC15bytes9BytesView2at(raw, i.val + 2 | 0));
        if (hi >= 0 && lo >= 0) {
          _M0MPC15array5Array4pushGyE(out$2, (hi << 4 | lo) & 255);
          i.val = i.val + 3 | 0;
          continue;
        }
      }
      _M0MPC15array5Array4pushGyE(out$2, _M0MPC15bytes9BytesView2at(raw, i.val));
      i.val = i.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(out$2, 0, out$2.length));
}
function _M0FP212moonbitstack7moonzip5crc32(data) {
  const crc = new _M0TPB8MutLocalGjE(-1);
  const _bind$6 = data.end - data.start | 0;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const b = data.buf[data.start + _ | 0];
      crc.val = crc.val ^ _M0MPC14byte4Byte8to__uint(b);
      const _bind$7 = 0;
      const _bind$8 = 8;
      let _tmp$5 = _bind$7;
      while (true) {
        const _$2 = _tmp$5;
        if (_$2 < _bind$8) {
          crc.val = (crc.val & 1) !== 0 ? (crc.val >>> 1 | 0) ^ -306674912 : crc.val >>> 1 | 0;
          _tmp$5 = _$2 + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return crc.val ^ -1;
}
function _M0MP312moonbitstack7moonzip7deflate6Reader4bits(self, count) {
  while (true) {
    if (self.held < count) {
      if (self.pos >= _M0MPC15bytes9BytesView6length(self.src)) {
        return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(self.pos));
      }
      self.acc = self.acc | _M0MPC15bytes9BytesView2at(self.src, self.pos) << self.held;
      self.pos = self.pos + 1 | 0;
      self.held = self.held + 8 | 0;
      continue;
    } else {
      break;
    }
  }
  const value = self.acc & ((1 << count) - 1 | 0);
  self.acc = self.acc >> count;
  self.held = self.held - count | 0;
  return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE2Ok(value);
}
function _M0MP312moonbitstack7moonzip7deflate7Huffman4read(self, br) {
  const code = new _M0TPB8MutLocalGiE(0);
  const first = new _M0TPB8MutLocalGiE(0);
  const index = new _M0TPB8MutLocalGiE(0);
  const _bind$6 = 1;
  const _bind$7 = 16;
  let _tmp$4 = _bind$6;
  while (true) {
    const width = _tmp$4;
    if (width < _bind$7) {
      const _tmp$5 = code.val;
      const _bind$8 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 1);
      let _tmp$6;
      if (_bind$8.$tag === 1) {
        const _ok = _bind$8;
        _tmp$6 = _ok._0;
      } else {
        return _bind$8;
      }
      code.val = _tmp$5 | _tmp$6;
      const _tmp$7 = self.counts;
      const count = width >>> 0 < _tmp$7.length ? _tmp$7[width] : $oob();
      if ((code.val - first.val | 0) < count) {
        const _tmp$8 = self.symbols;
        const _tmp$9 = index.val + (code.val - first.val | 0) | 0;
        return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE2Ok(_tmp$9 >>> 0 < _tmp$8.length ? _tmp$8[_tmp$9] : $oob());
      }
      index.val = index.val + count | 0;
      first.val = (first.val + count | 0) << 1;
      code.val = code.val << 1;
      _tmp$4 = width + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(br.pos));
}
function _M0FP312moonbitstack7moonzip7deflate5block(br, out$2, litlen, dist, ceiling) {
  const open = new _M0TPB8MutLocalGbE(true);
  while (true) {
    if (open.val) {
      if (ceiling >= 0 && out$2.length > ceiling) {
        return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eTooBig(ceiling));
      }
      const _bind$6 = _M0MP312moonbitstack7moonzip7deflate7Huffman4read(litlen, br);
      let sym;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        sym = _ok._0;
      } else {
        return _bind$6;
      }
      if (sym < 256) {
        _M0MPC15array5Array4pushGyE(out$2, sym & 255);
      } else {
        if (sym === 256) {
          open.val = false;
        } else {
          const index = sym - 257 | 0;
          if (index >= 29) {
            return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(br.pos));
          }
          const _tmp$4 = index >>> 0 < _M0FP312moonbitstack7moonzip7deflate12length__base.length ? _M0FP312moonbitstack7moonzip7deflate12length__base[index] : $oob();
          const _bind$7 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, index >>> 0 < _M0FP312moonbitstack7moonzip7deflate13length__extra.length ? _M0FP312moonbitstack7moonzip7deflate13length__extra[index] : $oob());
          let _tmp$5;
          if (_bind$7.$tag === 1) {
            const _ok = _bind$7;
            _tmp$5 = _ok._0;
          } else {
            return _bind$7;
          }
          const len = _tmp$4 + _tmp$5 | 0;
          const _bind$8 = _M0MP312moonbitstack7moonzip7deflate7Huffman4read(dist, br);
          let dcode;
          if (_bind$8.$tag === 1) {
            const _ok = _bind$8;
            dcode = _ok._0;
          } else {
            return _bind$8;
          }
          if (dcode >= 30) {
            return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(br.pos));
          }
          const _tmp$6 = dcode >>> 0 < _M0FP312moonbitstack7moonzip7deflate10dist__base.length ? _M0FP312moonbitstack7moonzip7deflate10dist__base[dcode] : $oob();
          const _bind$9 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, dcode >>> 0 < _M0FP312moonbitstack7moonzip7deflate11dist__extra.length ? _M0FP312moonbitstack7moonzip7deflate11dist__extra[dcode] : $oob());
          let _tmp$7;
          if (_bind$9.$tag === 1) {
            const _ok = _bind$9;
            _tmp$7 = _ok._0;
          } else {
            return _bind$9;
          }
          const back = _tmp$6 + _tmp$7 | 0;
          if (back > out$2.length) {
            return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eDistance(br.pos));
          }
          const start = out$2.length - back | 0;
          const _bind$10 = 0;
          let _tmp$8 = _bind$10;
          while (true) {
            const k = _tmp$8;
            if (k < len) {
              _M0MPC15array5Array4pushGyE(out$2, _M0MPC15array5Array2atGyE(out$2, start + k | 0));
              _tmp$8 = k + 1 | 0;
              continue;
            } else {
              break;
            }
          }
        }
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE2Ok(undefined);
}
function _M0MP312moonbitstack7moonzip7deflate7Huffman2of(lengths$2, n) {
  const counts = $make_array_len_and_init(16, 0);
  const _bind$6 = 0;
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < n) {
      const _array_1 = counts;
      const _index_2 = i >>> 0 < lengths$2.length ? lengths$2[i] : $oob();
      if (_index_2 >>> 0 < _array_1.length) {
        _array_1[_index_2] = (_index_2 >>> 0 < _array_1.length ? _array_1[_index_2] : $oob()) + 1 | 0;
      } else {
        $oob();
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (0 >>> 0 < counts.length) {
    counts[0] = 0;
  } else {
    $oob();
  }
  const offsets = $make_array_len_and_init(16, 0);
  const _bind$7 = 1;
  const _bind$8 = 16;
  let _tmp$5 = _bind$7;
  while (true) {
    const width = _tmp$5;
    if (width < _bind$8) {
      const _tmp$6 = width - 1 | 0;
      const _tmp$7 = _tmp$6 >>> 0 < offsets.length ? offsets[_tmp$6] : $oob();
      const _tmp$8 = width - 1 | 0;
      if (width >>> 0 < offsets.length) {
        offsets[width] = _tmp$7 + (_tmp$8 >>> 0 < counts.length ? counts[_tmp$8] : $oob()) | 0;
      } else {
        $oob();
      }
      _tmp$5 = width + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const symbols = $make_array_len_and_init(n > 0 ? n : 1, 0);
  const _bind$9 = 0;
  let _tmp$6 = _bind$9;
  while (true) {
    const i = _tmp$6;
    if (i < n) {
      if ((i >>> 0 < lengths$2.length ? lengths$2[i] : $oob()) !== 0) {
        const _tmp$7 = i >>> 0 < lengths$2.length ? lengths$2[i] : $oob();
        const _tmp$8 = _tmp$7 >>> 0 < offsets.length ? offsets[_tmp$7] : $oob();
        if (_tmp$8 >>> 0 < symbols.length) {
          symbols[_tmp$8] = i;
        } else {
          $oob();
        }
        const _array_3 = offsets;
        const _index_4 = i >>> 0 < lengths$2.length ? lengths$2[i] : $oob();
        if (_index_4 >>> 0 < _array_3.length) {
          _array_3[_index_4] = (_index_4 >>> 0 < _array_3.length ? _array_3[_index_4] : $oob()) + 1 | 0;
        } else {
          $oob();
        }
      }
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0TP312moonbitstack7moonzip7deflate7Huffman(counts, symbols);
}
function _M0FP312moonbitstack7moonzip7deflate6stored(br, out$2, ceiling) {
  br.acc = 0;
  br.held = 0;
  if ((br.pos + 4 | 0) > _M0MPC15bytes9BytesView6length(br.src)) {
    return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(br.pos));
  }
  const len = _M0MPC15bytes9BytesView2at(br.src, br.pos) | _M0MPC15bytes9BytesView2at(br.src, br.pos + 1 | 0) << 8;
  const nlen = _M0MPC15bytes9BytesView2at(br.src, br.pos + 2 | 0) | _M0MPC15bytes9BytesView2at(br.src, br.pos + 3 | 0) << 8;
  if (len !== (nlen ^ 65535)) {
    return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(br.pos, "a stored block's length and its complement disagree"));
  }
  br.pos = br.pos + 4 | 0;
  if ((br.pos + len | 0) > _M0MPC15bytes9BytesView6length(br.src)) {
    return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(br.pos));
  }
  if (ceiling >= 0 && (out$2.length + len | 0) > ceiling) {
    return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eTooBig(ceiling));
  }
  const _bind$6 = 0;
  let _tmp$4 = _bind$6;
  while (true) {
    const _ = _tmp$4;
    if (_ < len) {
      _M0MPC15array5Array4pushGyE(out$2, _M0MPC15bytes9BytesView2at(br.src, br.pos));
      br.pos = br.pos + 1 | 0;
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGuRP212moonbitstack7moonzip6BrokenE2Ok(undefined);
}
function _M0FP312moonbitstack7moonzip7deflate6tables(br) {
  const _bind$6 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 5);
  let _tmp$4;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    _tmp$4 = _ok._0;
  } else {
    return _bind$6;
  }
  const nlit = _tmp$4 + 257 | 0;
  const _bind$7 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 5);
  let _tmp$5;
  if (_bind$7.$tag === 1) {
    const _ok = _bind$7;
    _tmp$5 = _ok._0;
  } else {
    return _bind$7;
  }
  const ndist = _tmp$5 + 1 | 0;
  const _bind$8 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 4);
  let _tmp$6;
  if (_bind$8.$tag === 1) {
    const _ok = _bind$8;
    _tmp$6 = _ok._0;
  } else {
    return _bind$8;
  }
  const ncode = _tmp$6 + 4 | 0;
  const meta = $make_array_len_and_init(19, 0);
  const _bind$9 = 0;
  let _tmp$7 = _bind$9;
  while (true) {
    const i = _tmp$7;
    if (i < ncode) {
      const _tmp$8 = i >>> 0 < _M0FP312moonbitstack7moonzip7deflate13length__order.length ? _M0FP312moonbitstack7moonzip7deflate13length__order[i] : $oob();
      const _bind$10 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 3);
      let _tmp$9;
      if (_bind$10.$tag === 1) {
        const _ok = _bind$10;
        _tmp$9 = _ok._0;
      } else {
        return _bind$10;
      }
      if (_tmp$8 >>> 0 < meta.length) {
        meta[_tmp$8] = _tmp$9;
      } else {
        $oob();
      }
      _tmp$7 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const code_lengths = _M0MP312moonbitstack7moonzip7deflate7Huffman2of(meta, 19);
  const lengths$2 = $make_array_len_and_init(nlit + ndist | 0, 0);
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (i.val < (nlit + ndist | 0)) {
      const _bind$10 = _M0MP312moonbitstack7moonzip7deflate7Huffman4read(code_lengths, br);
      let sym;
      if (_bind$10.$tag === 1) {
        const _ok = _bind$10;
        sym = _ok._0;
      } else {
        return _bind$10;
      }
      if (sym < 16) {
        const _tmp$8 = i.val;
        if (_tmp$8 >>> 0 < lengths$2.length) {
          lengths$2[_tmp$8] = sym;
        } else {
          $oob();
        }
        i.val = i.val + 1 | 0;
      } else {
        let repeat;
        let value;
        _L: {
          switch (sym) {
            case 16: {
              if (i.val === 0) {
                return new _M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(br.pos));
              }
              const _bind$11 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 2);
              let _tmp$8;
              if (_bind$11.$tag === 1) {
                const _ok = _bind$11;
                _tmp$8 = _ok._0;
              } else {
                return _bind$11;
              }
              const _tmp$9 = 3 + _tmp$8 | 0;
              const _tmp$10 = i.val - 1 | 0;
              repeat = _tmp$9;
              value = _tmp$10 >>> 0 < lengths$2.length ? lengths$2[_tmp$10] : $oob();
              break _L;
            }
            case 17: {
              const _bind$12 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 3);
              let _tmp$11;
              if (_bind$12.$tag === 1) {
                const _ok = _bind$12;
                _tmp$11 = _ok._0;
              } else {
                return _bind$12;
              }
              repeat = 3 + _tmp$11 | 0;
              value = 0;
              break _L;
            }
            default: {
              const _bind$13 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 7);
              let _tmp$12;
              if (_bind$13.$tag === 1) {
                const _ok = _bind$13;
                _tmp$12 = _ok._0;
              } else {
                return _bind$13;
              }
              repeat = 11 + _tmp$12 | 0;
              value = 0;
              break _L;
            }
          }
        }
        if ((i.val + repeat | 0) > (nlit + ndist | 0)) {
          return new _M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error38moonbitstack_2fmoonzip_2eBroken_2eCode(br.pos));
        }
        const _bind$11 = 0;
        let _tmp$8 = _bind$11;
        while (true) {
          const _ = _tmp$8;
          if (_ < repeat) {
            const _tmp$9 = i.val;
            if (_tmp$9 >>> 0 < lengths$2.length) {
              lengths$2[_tmp$9] = value;
            } else {
              $oob();
            }
            i.val = i.val + 1 | 0;
            _tmp$8 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      }
      continue;
    } else {
      break;
    }
  }
  const lit = $make_array_len_and_init(nlit, 0);
  const _bind$10 = 0;
  let _tmp$8 = _bind$10;
  while (true) {
    const k = _tmp$8;
    if (k < nlit) {
      if (k >>> 0 < lit.length) {
        lit[k] = k >>> 0 < lengths$2.length ? lengths$2[k] : $oob();
      } else {
        $oob();
      }
      _tmp$8 = k + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const dist = $make_array_len_and_init(ndist, 0);
  const _bind$11 = 0;
  let _tmp$9 = _bind$11;
  while (true) {
    const k = _tmp$9;
    if (k < ndist) {
      const _tmp$10 = nlit + k | 0;
      if (k >>> 0 < dist.length) {
        dist[k] = _tmp$10 >>> 0 < lengths$2.length ? lengths$2[_tmp$10] : $oob();
      } else {
        $oob();
      }
      _tmp$9 = k + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGURP312moonbitstack7moonzip7deflate7HuffmanRP312moonbitstack7moonzip7deflate7HuffmanERP212moonbitstack7moonzip6BrokenE2Ok({ _0: _M0MP312moonbitstack7moonzip7deflate7Huffman2of(lit, nlit), _1: _M0MP312moonbitstack7moonzip7deflate7Huffman2of(dist, ndist) });
}
function _M0FP312moonbitstack7moonzip7deflate7inflate(data, limit) {
  let ceiling;
  if (limit === undefined) {
    ceiling = -1;
  } else {
    const _Some = limit;
    const _n = _Some;
    ceiling = _n;
  }
  const br = new _M0TP312moonbitstack7moonzip7deflate6Reader(data, 0, 0, 0);
  const out$2 = [];
  const last = new _M0TPB8MutLocalGbE(false);
  while (true) {
    if (!last.val) {
      const _bind$6 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 1);
      let _tmp$4;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _tmp$4 = _ok._0;
      } else {
        return _bind$6;
      }
      last.val = _tmp$4 === 1;
      const _bind$7 = _M0MP312moonbitstack7moonzip7deflate6Reader4bits(br, 2);
      let _bind$8;
      if (_bind$7.$tag === 1) {
        const _ok = _bind$7;
        _bind$8 = _ok._0;
      } else {
        return _bind$7;
      }
      switch (_bind$8) {
        case 0: {
          const _bind$9 = _M0FP312moonbitstack7moonzip7deflate6stored(br, out$2, ceiling);
          if (_bind$9.$tag === 1) {
            const _ok = _bind$9;
            _ok._0;
          } else {
            return _bind$9;
          }
          break;
        }
        case 1: {
          const _bind$10 = _M0FP312moonbitstack7moonzip7deflate5block(br, out$2, _M0FP312moonbitstack7moonzip7deflate13fixed__litlen, _M0FP312moonbitstack7moonzip7deflate11fixed__dist, ceiling);
          if (_bind$10.$tag === 1) {
            const _ok = _bind$10;
            _ok._0;
          } else {
            return _bind$10;
          }
          break;
        }
        case 2: {
          let litlen;
          let dist;
          _L: {
            const _bind$11 = _M0FP312moonbitstack7moonzip7deflate6tables(br);
            let _bind$12;
            if (_bind$11.$tag === 1) {
              const _ok = _bind$11;
              _bind$12 = _ok._0;
            } else {
              return _bind$11;
            }
            const _litlen = _bind$12._0;
            const _dist = _bind$12._1;
            litlen = _litlen;
            dist = _dist;
            break _L;
          }
          const _bind$11 = _M0FP312moonbitstack7moonzip7deflate5block(br, out$2, litlen, dist, ceiling);
          if (_bind$11.$tag === 1) {
            const _ok = _bind$11;
            _ok._0;
          } else {
            return _bind$11;
          }
          break;
        }
        default: {
          return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(br.pos, "a block type DEFLATE does not define"));
        }
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE2Ok(_M0MPC15bytes5Bytes11from__array(new _M0TPB9ArrayViewGyE(out$2, 0, out$2.length)));
}
function _M0FP312moonbitstack7moonzip4gzip5crc32(data) {
  return _M0FP212moonbitstack7moonzip5crc32(data);
}
function _M0FP312moonbitstack7moonzip4gzip12past__string(data, from) {
  const at = new _M0TPB8MutLocalGiE(from);
  while (true) {
    if (at.val < _M0MPC15bytes9BytesView6length(data) && _M0MPC15bytes9BytesView2at(data, at.val) !== 0) {
      at.val = at.val + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  if (at.val >= _M0MPC15bytes9BytesView6length(data)) {
    return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(at.val));
  }
  return new _M0DTPC16result6ResultGiRP212moonbitstack7moonzip6BrokenE2Ok(at.val + 1 | 0);
}
function _M0FP312moonbitstack7moonzip4gzip6read32(data, at) {
  const value = new _M0TPB8MutLocalGjE(0);
  const _bind$6 = 0;
  const _bind$7 = 4;
  let _tmp$4 = _bind$6;
  while (true) {
    const i = _tmp$4;
    if (i < _bind$7) {
      value.val = value.val | _M0MPC14byte4Byte8to__uint(_M0MPC15bytes9BytesView2at(data, at + i | 0)) << (Math.imul(i, 8) | 0);
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return value.val;
}
function _M0FP312moonbitstack7moonzip4gzip14gunzip_2einner(data, checksum, length, header_crc, limit) {
  if (_M0MPC15bytes9BytesView6length(data) < 18) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(_M0MPC15bytes9BytesView6length(data)));
  }
  if (_M0MPC15bytes9BytesView2at(data, 0) !== 31 || _M0MPC15bytes9BytesView2at(data, 1) !== 139) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(0, "not a gzip stream"));
  }
  if (_M0MPC15bytes9BytesView2at(data, 2) !== 8) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(2, "a compression method gzip does not define"));
  }
  const flags = _M0MPC15bytes9BytesView2at(data, 3);
  if ((flags & 224) !== 0) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eHeader(3, "a reserved flag is set"));
  }
  const at = new _M0TPB8MutLocalGiE(10);
  if ((flags & 4) !== 0) {
    if ((at.val + 2 | 0) > _M0MPC15bytes9BytesView6length(data)) {
      return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(at.val));
    }
    const len = _M0MPC15bytes9BytesView2at(data, at.val) | _M0MPC15bytes9BytesView2at(data, at.val + 1 | 0) << 8;
    at.val = at.val + (2 + len | 0) | 0;
  }
  if ((flags & 8) !== 0) {
    const _bind$6 = _M0FP312moonbitstack7moonzip4gzip12past__string(data, at.val);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      return _bind$6;
    }
    at.val = _tmp$4;
  }
  if ((flags & 16) !== 0) {
    const _bind$6 = _M0FP312moonbitstack7moonzip4gzip12past__string(data, at.val);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      return _bind$6;
    }
    at.val = _tmp$4;
  }
  if ((flags & 2) !== 0) {
    if ((at.val + 2 | 0) > _M0MPC15bytes9BytesView6length(data)) {
      return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(at.val));
    }
    if (header_crc) {
      const want = (_M0MPC14byte4Byte8to__uint(_M0MPC15bytes9BytesView2at(data, at.val)) | _M0MPC14byte4Byte8to__uint(_M0MPC15bytes9BytesView2at(data, at.val + 1 | 0)) << 8) & 65535;
      const got = _M0FP312moonbitstack7moonzip4gzip5crc32(_M0MPC15bytes9BytesView21clamped__view_2einner(data, 0, at.val)) & 65535;
      if (want !== got) {
        return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eChecksum(want, got));
      }
    }
    at.val = at.val + 2 | 0;
  }
  if ((at.val + 8 | 0) > _M0MPC15bytes9BytesView6length(data)) {
    return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error43moonbitstack_2fmoonzip_2eBroken_2eTruncated(at.val));
  }
  const end = _M0MPC15bytes9BytesView6length(data) - 8 | 0;
  const _bind$6 = _M0FP312moonbitstack7moonzip7deflate7inflate(_M0MPC15bytes9BytesView21clamped__view_2einner(data, at.val, end), limit);
  let body;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    body = _ok._0;
  } else {
    return _bind$6;
  }
  if (checksum) {
    const want_crc = _M0FP312moonbitstack7moonzip4gzip6read32(data, end);
    const got_crc = _M0FP312moonbitstack7moonzip4gzip5crc32(new _M0TPC15bytes9BytesView(body, 0, body.length));
    if (want_crc !== got_crc) {
      return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error42moonbitstack_2fmoonzip_2eBroken_2eChecksum(want_crc, got_crc));
    }
  }
  if (length) {
    const want_len = _M0FP312moonbitstack7moonzip4gzip6read32(data, end + 4 | 0);
    if (want_len !== (body.length & -1)) {
      return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE3Err(new _M0DTPC15error5Error40moonbitstack_2fmoonzip_2eBroken_2eLength(want_len, body.length));
    }
  }
  return new _M0DTPC16result6ResultGzRP212moonbitstack7moonzip6BrokenE2Ok(body);
}
function _M0MP312moonbitstack7moonrpc6client10ClientCall3new(id, path, authority, metadata, timeout, send_window) {
  return new _M0TP312moonbitstack7moonrpc6client10ClientCall(id, path, authority, metadata, timeout, $bytes_literal$0, 0, false, false, false, send_window, _M0MPC16buffer6Buffer14Buffer_2einner(0), 0, [], _M0FP312moonbitstack7moonrpc4wire21default__window__size, $bytes_literal$0, undefined, "", $bytes_literal$0, [], [], false, _M0MPC16buffer6Buffer14Buffer_2einner(0), false, false, false, false, false, false);
}
function _M0FP312moonbitstack7moonrpc6client29emit__request__header__frames(stream_id, block, end_stream, max_frame_in) {
  const max_frame = max_frame_in < 1 ? _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size : max_frame_in;
  const frames = [];
  if (block.length <= max_frame) {
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame7Headers(stream_id, block, end_stream, true, undefined, 0));
    return frames;
  }
  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame7Headers(stream_id, _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(block, 0, max_frame)), end_stream, false, undefined, 0));
  const off = new _M0TPB8MutLocalGiE(max_frame);
  while (true) {
    if (off.val < block.length) {
      const end = (off.val + max_frame | 0) < block.length ? off.val + max_frame | 0 : block.length;
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame12Continuation(stream_id, _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(block, off.val, end)), end === block.length));
      off.val = end;
      continue;
    } else {
      break;
    }
  }
  return frames;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client3new() {
  const _tmp$4 = _M0MP312moonbitstack8moonhttp5hpack7Encoder3new(undefined, -1);
  const _tmp$5 = _M0MP312moonbitstack8moonhttp5hpack7Decoder3new(undefined);
  const _bind$6 = [];
  const _tmp$6 = _M0MPB3Map3MapGiRP312moonbitstack7moonrpc6client10ClientCallE(new _M0TPB9ArrayViewGUiRP312moonbitstack7moonrpc6client10ClientCallEE(_bind$6, 0, 0), undefined);
  const _bind$7 = [];
  return new _M0TP312moonbitstack7moonrpc6client8H2Client(_tmp$4, _tmp$5, _tmp$6, 1, _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size, false, 0, _M0MPB3Map3MapGiRPC16buffer6BufferE(new _M0TPB9ArrayViewGUiRPC16buffer6BufferEE(_bind$7, 0, 0), undefined));
}
function _M0MP312moonbitstack7moonrpc6client8H2Client7preface(self) {
  return [new _M0DTP312moonbitstack8moonhttp5http25Frame8Settings([{ _0: _M0FP312moonbitstack8moonhttp5http222settings__enable__push, _1: 0 }], false)];
}
function _M0FP312moonbitstack7moonrpc6client21encode__grpc__timeout(millis) {
  if (millis <= 99999999) {
    const _bind$6 = _M0MPC13int3Int18to__string_2einner(millis, 10);
    return _M0IPC15bytes5BytesPB3Add3add(_M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), false), $bytes_literal$7);
  } else {
    if (1000 === 0) {
      $panic();
    }
    const _bind$6 = _M0MPC13int3Int18to__string_2einner(millis / 1000 | 0, 10);
    return _M0IPC15bytes5BytesPB3Add3add(_M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), false), $bytes_literal$8);
  }
}
function _M0MP312moonbitstack7moonrpc6client8H2Client12open_2einner(self, path, metadata, authority, timeout_millis) {
  if (self.goaway_received) {
    return 0;
  }
  const id = self.next_id;
  self.next_id = self.next_id + 2 | 0;
  let timeout;
  let ms;
  _L: {
    _L$2: {
      if (timeout_millis === undefined) {
        timeout = undefined;
      } else {
        const _Some = timeout_millis;
        const _ms = _Some;
        ms = _ms;
        break _L$2;
      }
      break _L;
    }
    timeout = _M0FP312moonbitstack7moonrpc6client21encode__grpc__timeout(ms);
  }
  const call = _M0MP312moonbitstack7moonrpc6client10ClientCall3new(id, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(path, 0, path.length), false), _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(authority, 0, authority.length), false), metadata, timeout, self.remote_initial_window);
  _M0MPB3Map3setGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, id, call);
  return id;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client4open(self, path, metadata$46$opt, authority$46$opt, timeout_millis) {
  let metadata;
  if (metadata$46$opt.$tag === 1) {
    const _Some = metadata$46$opt;
    metadata = _Some._0;
  } else {
    metadata = [];
  }
  let authority;
  if (authority$46$opt === undefined) {
    authority = "127.0.0.1";
  } else {
    const _Some = authority$46$opt;
    authority = _Some;
  }
  return _M0MP312moonbitstack7moonrpc6client8H2Client12open_2einner(self, path, metadata, authority, timeout_millis);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client16produce__request(self, c) {
  const frames = [];
  if (!c.req_headers_sent) {
    const headers = [new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$9, $bytes_literal$10), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$11, $bytes_literal$12), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$13, c.path), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$14, c.authority), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$2, $bytes_literal$15), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$1, $bytes_literal$16)];
    let t;
    _L: {
      _L$2: {
        const _bind$6 = c.timeout;
        if (_bind$6 === undefined) {
        } else {
          const _Some = _bind$6;
          const _t = _Some;
          t = _t;
          break _L$2;
        }
        break _L;
      }
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(headers, new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$3, t));
    }
    const _bind$6 = c.metadata;
    const _bind$7 = _bind$6.length;
    let _tmp$4 = 0;
    while (true) {
      const _ = _tmp$4;
      if (_ < _bind$7) {
        const h = _bind$6[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(headers, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire25metadata__value__to__wire(h.name, h.value)));
        _tmp$4 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const block = _M0MP312moonbitstack8moonhttp5hpack7Encoder6encode(self.encoder, new _M0TPB9ArrayViewGRP312moonbitstack8moonhttp6header6HeaderE(headers, 0, headers.length));
    const end = c.req_ended && c.out.length === 0;
    const _bind$8 = _M0FP312moonbitstack7moonrpc6client29emit__request__header__frames(c.id, block, end, self.remote_max_frame);
    const _bind$9 = _bind$8.length;
    let _tmp$5 = 0;
    while (true) {
      const _ = _tmp$5;
      if (_ < _bind$9) {
        const f = _bind$8[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
        _tmp$5 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    c.req_headers_sent = true;
    if (end) {
      c.req_fin_sent = true;
    }
  }
  while (true) {
    if (c.out_off < c.out.length) {
      const remaining = c.out.length - c.out_off | 0;
      const budget = _M0FPC13cmp7minimumGiE(_M0FPC13cmp7minimumGiE(self.conn_send_window, c.send_window), self.remote_max_frame);
      if (budget <= 0) {
        break;
      }
      const n = remaining < budget ? remaining : budget;
      const chunk = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(c.out, c.out_off, c.out_off + n | 0));
      c.out_off = c.out_off + n | 0;
      self.conn_send_window = self.conn_send_window - n | 0;
      c.send_window = c.send_window - n | 0;
      const last = c.out_off >= c.out.length && c.req_ended;
      if (last) {
        c.req_fin_sent = true;
      }
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame4Data(c.id, chunk, last, 0));
      continue;
    } else {
      break;
    }
  }
  if (c.req_ended && (!c.req_fin_sent && c.out_off >= c.out.length)) {
    c.req_fin_sent = true;
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame4Data(c.id, $bytes_literal$0, true, 0));
  }
  return frames;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(self, id, message, end) {
  let c;
  _L: {
    const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, id);
    if (_bind$6 === undefined) {
      return [];
    } else {
      const _Some = _bind$6;
      const _c = _Some;
      c = _c;
      break _L;
    }
  }
  c.out = _M0IPC15bytes5BytesPB3Add3add(c.out, _M0FP312moonbitstack7moonrpc4wire23encode__message_2einner(message, false));
  if (end) {
    c.req_ended = true;
  }
  return _M0MP312moonbitstack7moonrpc6client8H2Client16produce__request(self, c);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client11close__send(self, id) {
  let c;
  _L: {
    const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, id);
    if (_bind$6 === undefined) {
      return [];
    } else {
      const _Some = _bind$6;
      const _c = _Some;
      c = _c;
      break _L;
    }
  }
  c.req_ended = true;
  return _M0MP312moonbitstack7moonrpc6client8H2Client16produce__request(self, c);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client13unary_2einner(self, path, request, metadata, authority, timeout_millis) {
  const id = _M0MP312moonbitstack7moonrpc6client8H2Client12open_2einner(self, path, metadata, authority, timeout_millis);
  return { _0: id, _1: _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(self, id, request, true) };
}
function _M0MP312moonbitstack7moonrpc6client8H2Client5unary(self, path, request, metadata$46$opt, authority$46$opt, timeout_millis) {
  let metadata;
  if (metadata$46$opt.$tag === 1) {
    const _Some = metadata$46$opt;
    metadata = _Some._0;
  } else {
    metadata = [];
  }
  let authority;
  if (authority$46$opt === undefined) {
    authority = "127.0.0.1";
  } else {
    const _Some = authority$46$opt;
    authority = _Some;
  }
  return _M0MP312moonbitstack7moonrpc6client8H2Client13unary_2einner(self, path, request, metadata, authority, timeout_millis);
}
function _M0FP312moonbitstack7moonrpc6client21drain__call__messages(c) {
  const all = _M0MPC16buffer6Buffer9to__bytes(c.data);
  const n = all.length;
  const off = new _M0TPB8MutLocalGiE(c.data_off);
  while (true) {
    if ((n - off.val | 0) >= 5) {
      const _tmp$4 = off.val;
      const compressed = (_tmp$4 >>> 0 < all.length ? all[_tmp$4] : $oob()) !== 0;
      const len = _M0MPC16option6Option6unwrapGiE(_M0FP312moonbitstack7moonrpc4wire20message__len_2einner(new _M0TPC15bytes9BytesView(all, 0, all.length), off.val));
      if (len < 0 || len > _M0FP312moonbitstack7moonrpc4wire18max__message__size) {
        const _bind$6 = c.grpc_status;
        if (_bind$6 === undefined) {
          c.grpc_status = _M0MP312moonbitstack7moonrpc4wire6Status4code(8);
        }
        break;
      }
      if ((n - off.val | 0) < (5 + len | 0)) {
        break;
      }
      const body = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(all, off.val + 5 | 0, (off.val + 5 | 0) + len | 0));
      if (compressed) {
        if ($bytes_equal(c.resp_encoding, $bytes_literal$17)) {
          let m;
          _L: {
            _L$2: {
              let _bind$6;
              let _try_err;
              _L$3: {
                _L$4: {
                  const _bind$7 = _M0FP312moonbitstack7moonzip4gzip14gunzip_2einner(new _M0TPC15bytes9BytesView(body, 0, body.length), true, true, true, undefined);
                  if (_bind$7.$tag === 1) {
                    const _ok = _bind$7;
                    _bind$6 = _ok._0;
                  } else {
                    const _err = _bind$7;
                    _try_err = _err._0;
                    break _L$4;
                  }
                  break _L$3;
                }
                _bind$6 = undefined;
              }
              if (_bind$6 === undefined) {
                c.decode_failed = true;
              } else {
                const _Some = _bind$6;
                const _m = _Some;
                m = _m;
                break _L$2;
              }
              break _L;
            }
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(c.messages, m);
          }
        } else {
          c.decode_failed = true;
        }
      } else {
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(c.messages, body);
      }
      off.val = (off.val + 5 | 0) + len | 0;
      continue;
    } else {
      break;
    }
  }
  c.data_off = off.val;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client14apply__setting(self, id, value) {
  if (id === _M0FP312moonbitstack8moonhttp5http231settings__initial__window__size) {
    if (value < 0) {
      return undefined;
    }
    const delta = value - self.remote_initial_window | 0;
    self.remote_initial_window = value;
    const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls);
    while (true) {
      let c;
      _L: {
        const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6client10ClientCallE(_it);
        if (_bind$6 === undefined) {
          return;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          const _c = _x._1;
          c = _c;
          break _L;
        }
      }
      c.send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(c.send_window, delta);
      continue;
    }
  } else {
    if (id === _M0FP312moonbitstack8moonhttp5http226settings__max__frame__size) {
      self.remote_max_frame = value < _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size ? _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size : value > 16777215 ? 16777215 : value;
      return;
    } else {
      if (id === _M0FP312moonbitstack8moonhttp5http229settings__header__table__size) {
        if (value >= 0) {
          _M0MP312moonbitstack8moonhttp5hpack5Table6resize(self.encoder.table, value);
          return;
        } else {
          return;
        }
      } else {
        return;
      }
    }
  }
}
function _M0FP312moonbitstack7moonrpc6client21ascii__bytes__to__int(b) {
  const n = new _M0TPB8MutLocalGiE(0);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < b.length) {
      const c = i >>> 0 < b.length ? b[i] : $oob();
      if (c < 48 || c > 57) {
        break;
      }
      n.val = (Math.imul(n.val, 10) | 0) + (c - 48 | 0) | 0;
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return n.val;
}
function _M0FP312moonbitstack7moonrpc6client15percent__decode(v) {
  const _bind$6 = _M0FP212moonbitstack7moonurl8unescape(new _M0TPC15bytes9BytesView(v, 0, v.length));
  return _M0FPC28encoding4utf821decode__lossy_2einner(new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), false);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client16deliver__headers(self, c) {
  const _tmp$4 = self.decoder;
  const _bind$6 = _M0MPC16buffer6Buffer9to__bytes(c.header_block);
  const _bind$7 = _M0MP312moonbitstack8moonhttp5hpack7Decoder6decode(_tmp$4, new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), undefined);
  let headers;
  if (_bind$7.$tag === 1) {
    const _ok = _bind$7;
    headers = _ok._0;
  } else {
    return _bind$7;
  }
  const initial = !c.headers_seen && !c.pending_end_stream;
  if (initial) {
    c.committed = true;
  }
  const _bind$8 = headers.length;
  let _tmp$5 = 0;
  while (true) {
    const _ = _tmp$5;
    if (_ < _bind$8) {
      const h = headers[_];
      if ($bytes_equal(h.name, $bytes_literal$18)) {
        c.status = h.value;
      } else {
        if ($bytes_equal(h.name, $bytes_literal$19)) {
          c.grpc_status = _M0FP312moonbitstack7moonrpc6client21ascii__bytes__to__int(h.value);
        } else {
          if ($bytes_equal(h.name, $bytes_literal$20)) {
            c.grpc_message = _M0FP312moonbitstack7moonrpc6client15percent__decode(h.value);
          } else {
            if ($bytes_equal(h.name, $bytes_literal$4)) {
              c.resp_encoding = h.value;
            } else {
              if (initial) {
                if (!_M0FP412moonbitstack7moonrpc8internal2h220is__reserved__header(h.name)) {
                  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(c.resp_headers, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire27metadata__value__from__wire(h.name, h.value)));
                }
              } else {
                _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(c.resp_trailers, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire27metadata__value__from__wire(h.name, h.value)));
              }
            }
          }
        }
      }
      _tmp$5 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  c.headers_seen = true;
  _M0MPC16buffer6Buffer5reset(c.header_block);
  c.in_headers = false;
  if (c.pending_end_stream) {
    c.done = true;
  }
  return new _M0DTPC16result6ResultGuRPC15error5ErrorE2Ok(undefined);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client20drain__orphan__block(self, stream_id, fragment, end_headers) {
  let buf;
  const _bind$6 = _M0MPB3Map3getGiRPC16buffer6BufferE(self.orphan_blocks, stream_id);
  if (_bind$6 === undefined) {
    const b = _M0MPC16buffer6Buffer14Buffer_2einner(0);
    _M0MPB3Map3setGiRPC16buffer6BufferE(self.orphan_blocks, stream_id, b);
    buf = b;
  } else {
    const _Some = _bind$6;
    const _b = _Some;
    buf = _b;
  }
  _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(fragment, 0, fragment.length));
  const _bind$7 = _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(buf);
  if (_bind$7.$tag === 1) {
    const _ok = _bind$7;
    _ok._0;
  } else {
    return _bind$7;
  }
  if (end_headers) {
    const _tmp$4 = self.decoder;
    const _bind$8 = _M0MPC16buffer6Buffer9to__bytes(buf);
    const _bind$9 = _M0MP312moonbitstack8moonhttp5hpack7Decoder6decode(_tmp$4, new _M0TPC15bytes9BytesView(_bind$8, 0, _bind$8.length), undefined);
    if (_bind$9.$tag === 1) {
      const _ok = _bind$9;
      _ok._0;
    } else {
      return _bind$9;
    }
    _M0MPB3Map6removeGiRPC16buffer6BufferE(self.orphan_blocks, stream_id);
  }
  return new _M0DTPC16result6ResultGuRPC15error5ErrorE2Ok(undefined);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client14pump__requests(self) {
  const frames = [];
  const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls);
  while (true) {
    let c;
    _L: {
      const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6client10ClientCallE(_it);
      if (_bind$6 === undefined) {
        break;
      } else {
        const _Some = _bind$6;
        const _x = _Some;
        const _c = _x._1;
        c = _c;
        break _L;
      }
    }
    if (c.req_headers_sent && !c.req_fin_sent) {
      const _bind$6 = _M0MP312moonbitstack7moonrpc6client8H2Client16produce__request(self, c);
      const _bind$7 = _bind$6.length;
      let _tmp$4 = 0;
      while (true) {
        const _ = _tmp$4;
        if (_ < _bind$7) {
          const f = _bind$6[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
          _tmp$4 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    }
    continue;
  }
  return frames;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client9replenish(self, c) {
  const frames = [];
  if (2 === 0) {
    $panic();
  }
  const threshold = _M0FP312moonbitstack7moonrpc4wire21default__window__size / 2 | 0;
  if (self.conn_recv_window < threshold) {
    const inc = _M0FP312moonbitstack7moonrpc4wire21default__window__size - self.conn_recv_window | 0;
    self.conn_recv_window = self.conn_recv_window + inc | 0;
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate(0, inc));
  }
  if (c.recv_window < threshold) {
    const inc = _M0FP312moonbitstack7moonrpc4wire21default__window__size - c.recv_window | 0;
    c.recv_window = c.recv_window + inc | 0;
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate(c.id, inc));
  }
  return frames;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client4feed(self, frame) {
  _L: {
    let last_stream_id;
    _L$2: {
      let stream_id;
      let error_code;
      _L$3: {
        let end_stream;
        let stream_id$2;
        let data;
        let padding;
        _L$4: {
          let fragment;
          let stream_id$3;
          let end_headers;
          _L$5: {
            let end_stream$2;
            let stream_id$4;
            let fragment$2;
            let end_headers$2;
            _L$6: {
              let stream_id$5;
              let increment;
              _L$7: {
                let payload;
                let ack;
                _L$8: {
                  let params;
                  let ack$2;
                  _L$9: {
                    switch (frame.$tag) {
                      case 4: {
                        const _Settings = frame;
                        const _params = _Settings._0;
                        const _ack = _Settings._1;
                        params = _params;
                        ack$2 = _ack;
                        break _L$9;
                      }
                      case 6: {
                        const _Ping = frame;
                        const _payload = _Ping._0;
                        const _ack$2 = _Ping._1;
                        payload = _payload;
                        ack = _ack$2;
                        break _L$8;
                      }
                      case 8: {
                        const _WindowUpdate = frame;
                        const _stream_id = _WindowUpdate._0;
                        const _increment = _WindowUpdate._1;
                        stream_id$5 = _stream_id;
                        increment = _increment;
                        break _L$7;
                      }
                      case 1: {
                        const _Headers = frame;
                        const _stream_id$2 = _Headers._0;
                        const _fragment = _Headers._1;
                        const _end_stream = _Headers._2;
                        const _end_headers = _Headers._3;
                        end_stream$2 = _end_stream;
                        stream_id$4 = _stream_id$2;
                        fragment$2 = _fragment;
                        end_headers$2 = _end_headers;
                        break _L$6;
                      }
                      case 9: {
                        const _Continuation = frame;
                        const _stream_id$3 = _Continuation._0;
                        const _fragment$2 = _Continuation._1;
                        const _end_headers$2 = _Continuation._2;
                        fragment = _fragment$2;
                        stream_id$3 = _stream_id$3;
                        end_headers = _end_headers$2;
                        break _L$5;
                      }
                      case 0: {
                        const _Data = frame;
                        const _stream_id$4 = _Data._0;
                        const _data = _Data._1;
                        const _end_stream$2 = _Data._2;
                        const _padding = _Data._3;
                        end_stream = _end_stream$2;
                        stream_id$2 = _stream_id$4;
                        data = _data;
                        padding = _padding;
                        break _L$4;
                      }
                      case 3: {
                        const _RstStream = frame;
                        const _stream_id$5 = _RstStream._0;
                        const _error_code = _RstStream._1;
                        stream_id = _stream_id$5;
                        error_code = _error_code;
                        break _L$3;
                      }
                      case 7: {
                        const _GoAway = frame;
                        const _last_stream_id = _GoAway._0;
                        last_stream_id = _last_stream_id;
                        break _L$2;
                      }
                      case 2: {
                        break _L;
                      }
                      case 5: {
                        break _L;
                      }
                      default: {
                        break _L;
                      }
                    }
                  }
                  if (ack$2) {
                    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
                  } else {
                    const _bind$6 = params.length;
                    let _tmp$4 = 0;
                    while (true) {
                      const _ = _tmp$4;
                      if (_ < _bind$6) {
                        const p = params[_];
                        _M0MP312moonbitstack7moonrpc6client8H2Client14apply__setting(self, p._0, p._1);
                        _tmp$4 = _ + 1 | 0;
                        continue;
                      } else {
                        break;
                      }
                    }
                    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([new _M0DTP312moonbitstack8moonhttp5http25Frame8Settings([], true)]);
                  }
                }
                return ack ? new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]) : new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([new _M0DTP312moonbitstack8moonhttp5http25Frame4Ping(payload, true)]);
              }
              if (stream_id$5 === 0) {
                self.conn_send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(self.conn_send_window, increment);
              } else {
                let c;
                _L$8: {
                  _L$9: {
                    const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, stream_id$5);
                    if (_bind$6 === undefined) {
                    } else {
                      const _Some = _bind$6;
                      const _c = _Some;
                      c = _c;
                      break _L$9;
                    }
                    break _L$8;
                  }
                  c.send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(c.send_window, increment);
                }
              }
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok(_M0MP312moonbitstack7moonrpc6client8H2Client14pump__requests(self));
            }
            let c;
            _L$7: {
              _L$8: {
                const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, stream_id$4);
                if (_bind$6 === undefined) {
                  const _bind$7 = _M0MP312moonbitstack7moonrpc6client8H2Client20drain__orphan__block(self, stream_id$4, fragment$2, end_headers$2);
                  if (_bind$7.$tag === 1) {
                    const _ok = _bind$7;
                    _ok._0;
                  } else {
                    return _bind$7;
                  }
                } else {
                  const _Some = _bind$6;
                  const _c = _Some;
                  c = _c;
                  break _L$8;
                }
                break _L$7;
              }
              _M0MPC16buffer6Buffer12write__bytes(c.header_block, new _M0TPC15bytes9BytesView(fragment$2, 0, fragment$2.length));
              const _bind$6 = _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(c.header_block);
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                _ok._0;
              } else {
                return _bind$6;
              }
              c.pending_end_stream = end_stream$2;
              if (end_headers$2) {
                const _bind$7 = _M0MP312moonbitstack7moonrpc6client8H2Client16deliver__headers(self, c);
                if (_bind$7.$tag === 1) {
                  const _ok = _bind$7;
                  _ok._0;
                } else {
                  return _bind$7;
                }
              } else {
                c.in_headers = true;
              }
            }
            return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
          }
          let c;
          _L$6: {
            const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, stream_id$3);
            if (_bind$6 === undefined) {
              const _bind$7 = _M0MP312moonbitstack7moonrpc6client8H2Client20drain__orphan__block(self, stream_id$3, fragment, end_headers);
              if (_bind$7.$tag === 1) {
                const _ok = _bind$7;
                _ok._0;
              } else {
                return _bind$7;
              }
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
            } else {
              const _Some = _bind$6;
              const _c = _Some;
              c = _c;
              break _L$6;
            }
          }
          if (c.in_headers) {
            _M0MPC16buffer6Buffer12write__bytes(c.header_block, new _M0TPC15bytes9BytesView(fragment, 0, fragment.length));
            const _bind$6 = _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(c.header_block);
            if (_bind$6.$tag === 1) {
              const _ok = _bind$6;
              _ok._0;
            } else {
              return _bind$6;
            }
            if (end_headers) {
              const _bind$7 = _M0MP312moonbitstack7moonrpc6client8H2Client16deliver__headers(self, c);
              if (_bind$7.$tag === 1) {
                const _ok = _bind$7;
                _ok._0;
              } else {
                return _bind$7;
              }
            }
          }
          return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
        }
        let c;
        _L$5: {
          const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, stream_id$2);
          if (_bind$6 === undefined) {
            return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
          } else {
            const _Some = _bind$6;
            const _c = _Some;
            c = _c;
            break _L$5;
          }
        }
        const flow = (data.length + padding | 0) + (padding > 0 ? 1 : 0) | 0;
        self.conn_recv_window = self.conn_recv_window - flow | 0;
        c.recv_window = c.recv_window - flow | 0;
        _M0MPC16buffer6Buffer12write__bytes(c.data, new _M0TPC15bytes9BytesView(data, 0, data.length));
        _M0FP312moonbitstack7moonrpc6client21drain__call__messages(c);
        if (end_stream) {
          c.done = true;
        }
        return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok(_M0MP312moonbitstack7moonrpc6client8H2Client9replenish(self, c));
      }
      let c;
      _L$4: {
        _L$5: {
          const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, stream_id);
          if (_bind$6 === undefined) {
          } else {
            const _Some = _bind$6;
            const _c = _Some;
            c = _c;
            break _L$5;
          }
          break _L$4;
        }
        c.done = true;
        const _bind$6 = c.grpc_status;
        if (_bind$6 === undefined) {
          c.grpc_status = _M0MP312moonbitstack7moonrpc4wire6Status4code(_M0MP312moonbitstack7moonrpc4wire6Status15from__h2__error(error_code));
        }
        if (error_code === _M0FP312moonbitstack8moonhttp5http222error__refused__stream) {
          c.unprocessed = true;
        }
      }
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
    }
    self.goaway_received = true;
    self.goaway_last_stream_id = last_stream_id;
    const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls);
    while (true) {
      let c;
      _L$3: {
        const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6client10ClientCallE(_it);
        if (_bind$6 === undefined) {
          break;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          const _c = _x._1;
          c = _c;
          break _L$3;
        }
      }
      if (c.id > last_stream_id) {
        c.unprocessed = true;
      }
      continue;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERPC15error5ErrorE2Ok([]);
}
function _M0MP312moonbitstack7moonrpc6client8H2Client8is__done(self, id) {
  let c;
  _L: {
    const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, id);
    if (_bind$6 === undefined) {
      return true;
    } else {
      const _Some = _bind$6;
      const _c = _Some;
      c = _c;
      break _L;
    }
  }
  return c.done;
}
function _M0MP312moonbitstack7moonrpc6client8H2Client5reply(self, id) {
  let c;
  _L: {
    const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6client10ClientCallE(self.calls, id);
    if (_bind$6 === undefined) {
      return new _M0TP312moonbitstack7moonrpc6client9CallReply($bytes_literal$0, -1, "", [], [], [], false, false);
    } else {
      const _Some = _bind$6;
      const _c = _Some;
      c = _c;
      break _L;
    }
  }
  let grpc;
  if (c.decode_failed) {
    grpc = _M0MP312moonbitstack7moonrpc4wire6Status4code(13);
  } else {
    const _bind$6 = c.grpc_status;
    if (_bind$6 === undefined) {
      const http = _M0FP312moonbitstack7moonrpc6client21ascii__bytes__to__int(c.status);
      grpc = c.status.length === 0 || http === 200 ? -1 : _M0MP312moonbitstack7moonrpc4wire6Status4code(_M0MP312moonbitstack7moonrpc4wire6Status10from__http(http));
    } else {
      const _Some = _bind$6;
      const _v = _Some;
      grpc = _v;
    }
  }
  return new _M0TP312moonbitstack7moonrpc6client9CallReply(c.status, grpc, c.grpc_message, c.resp_headers, c.messages, c.resp_trailers, c.committed, c.unprocessed);
}
function _M0IP312moonbitstack7moonvar6leb1287RefusedPB4Show6output(self, logger) {
  let limit;
  let got;
  _L: {
    let m;
    _L$2: {
      if (self.$tag === 14) {
        const _Truncated = self;
        const _m = _Truncated._0;
        m = _m;
        break _L$2;
      } else {
        const _Exceeded = self;
        const _limit = _Exceeded._0;
        const _got = _Exceeded._1;
        limit = _limit;
        got = _got;
        break _L;
      }
    }
    logger.method_table.method_0(logger.self, `Truncated(${m})`);
    return;
  }
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(22);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "Exceeded(limit=");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, limit);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ", got=");
  _M0MPB13StringBuilder13write__objectGiE(_string_builder, got);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, ")");
  logger.method_table.method_0(logger.self, _M0MPB13StringBuilder10to__string(_string_builder));
}
function _M0FP312moonbitstack7moonvar6leb1285write(buf, v) {
  const rest = new _M0TPB8MutLocalGmE(v);
  while (true) {
    if (BigInt.asUintN(64, rest.val) >= BigInt.asUintN(64, 128n)) {
      _M0MPC16buffer6Buffer11write__byte(buf, _M0MPC16uint646UInt648to__byte(BigInt.asUintN(64, BigInt.asUintN(64, rest.val & 127n) | 128n)));
      rest.val = BigInt.asUintN(64, BigInt.asUintN(64, rest.val) >> BigInt(7 & 63));
      continue;
    } else {
      break;
    }
  }
  _M0MPC16buffer6Buffer11write__byte(buf, _M0MPC16uint646UInt648to__byte(rest.val));
}
function _M0FP312moonbitstack7moonvar6leb12814decode_2einner(b, at) {
  const out$2 = new _M0TPB8MutLocalGmE(0n);
  const shift = new _M0TPB8MutLocalGiE(0);
  const used = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (used.val >= _M0FP312moonbitstack7moonvar6leb1285limit) {
      return new _M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE3Err(new _M0DTPC15error5Error52moonbitstack_2fmoonvar_2fleb128_2eRefused_2eExceeded(_M0FP312moonbitstack7moonvar6leb1285limit, used.val + 1 | 0));
    }
    if ((at + used.val | 0) >= _M0MPC15bytes9BytesView6length(b) || at < 0) {
      return new _M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE3Err(new _M0DTPC15error5Error53moonbitstack_2fmoonvar_2fleb128_2eRefused_2eTruncated("the value continues past the end"));
    }
    const octet = _M0MPC15bytes9BytesView2at(b, at + used.val | 0);
    used.val = used.val + 1 | 0;
    out$2.val = BigInt.asUintN(64, out$2.val | BigInt.asUintN(64, _M0MPC13int3Int10to__uint64(octet & 127) << BigInt(shift.val & 63)));
    if ((octet & 128) === 0) {
      break;
    }
    shift.val = shift.val + 7 | 0;
    continue;
  }
  return new _M0DTPC16result6ResultGUmiERP312moonbitstack7moonvar6leb1287RefusedE2Ok({ _0: out$2.val, _1: used.val });
}
function _M0MP312moonbitstack7moonrpc5proto8WireType4code(self) {
  switch (self) {
    case 0: {
      return 0;
    }
    case 1: {
      return 1;
    }
    case 2: {
      return 2;
    }
    default: {
      return 5;
    }
  }
}
function _M0MP312moonbitstack7moonrpc5proto8WireType10from__code(n) {
  switch (n) {
    case 0: {
      return 0;
    }
    case 1: {
      return 1;
    }
    case 2: {
      return 2;
    }
    case 5: {
      return 3;
    }
    default: {
      return undefined;
    }
  }
}
function _M0IP312moonbitstack7moonrpc5proto7PbErrorPB4Show6output(self, logger) {
  let n;
  _L: {
    switch (self.$tag) {
      case 3: {
        logger.method_table.method_0(logger.self, "Truncated");
        return;
      }
      case 2: {
        const _BadWireType = self;
        const _n = _BadWireType._0;
        n = _n;
        break _L;
      }
      case 1: {
        logger.method_table.method_0(logger.self, "Overflow");
        return;
      }
      default: {
        logger.method_table.method_0(logger.self, "BadUtf8");
        return;
      }
    }
  }
  logger.method_table.method_0(logger.self, `BadWireType(${_M0MPC13int3Int18to__string_2einner(n, 10)})`);
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter3new() {
  return new _M0TP312moonbitstack7moonrpc5proto8PbWriter(_M0MPC16buffer6Buffer14Buffer_2einner(0));
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(self) {
  return _M0MPC16buffer6Buffer9to__bytes(self.buf);
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter13write__varint(self, value) {
  _M0FP312moonbitstack7moonvar6leb1285write(self.buf, value);
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter10write__tag(self, field, wire) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter13write__varint(self, _M0MPC13int3Int10to__uint64(field << 3 | _M0MP312moonbitstack7moonrpc5proto8WireType4code(wire)));
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter17write__len__delim(self, body) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter13write__varint(self, _M0MPC13int3Int10to__uint64(body.length));
  _M0MPC16buffer6Buffer12write__bytes(self.buf, new _M0TPC15bytes9BytesView(body, 0, body.length));
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter5int32(self, field, v) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter10write__tag(self, field, 0);
  _M0MP312moonbitstack7moonrpc5proto8PbWriter13write__varint(self, BigInt.asUintN(64, BigInt(v)));
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter7bytes__(self, field, v) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter10write__tag(self, field, 2);
  _M0MP312moonbitstack7moonrpc5proto8PbWriter17write__len__delim(self, v);
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(self, field, v) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter10write__tag(self, field, 2);
  _M0MP312moonbitstack7moonrpc5proto8PbWriter17write__len__delim(self, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(v, 0, v.length), false));
}
function _M0MP312moonbitstack7moonrpc5proto8PbWriter9message__(self, field, v) {
  _M0MP312moonbitstack7moonrpc5proto8PbWriter10write__tag(self, field, 2);
  _M0MP312moonbitstack7moonrpc5proto8PbWriter17write__len__delim(self, v);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader3new(data) {
  return new _M0TP312moonbitstack7moonrpc5proto8PbReader(data, 0);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader3eof(self) {
  return self.pos >= self.data.length;
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader12read__varint(self) {
  let value;
  let used;
  _L: {
    let _bind$6;
    let _try_err;
    _L$2: {
      _L$3: {
        const _bind$7 = self.data;
        const _bind$8 = _M0FP312moonbitstack7moonvar6leb12814decode_2einner(new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length), self.pos);
        if (_bind$8.$tag === 1) {
          const _ok = _bind$8;
          _bind$6 = _ok._0;
        } else {
          const _err = _bind$8;
          _try_err = _err._0;
          break _L$3;
        }
        break _L$2;
      }
      if (_try_err.$tag === 13) {
        return new _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error51moonbitstack_2fmoonrpc_2fproto_2ePbError_2eOverflow__);
      } else {
        return new _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated__);
      }
    }
    const _value = _bind$6._0;
    const _used = _bind$6._1;
    value = _value;
    used = _used;
    break _L;
  }
  self.pos = self.pos + used | 0;
  return new _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(value);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader9read__tag(self) {
  const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader12read__varint(self);
  let _tmp$4;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    _tmp$4 = _ok._0;
  } else {
    return _bind$6;
  }
  const tag = Number(BigInt.asIntN(32, _tmp$4)) | 0;
  const field = tag >> 3;
  let w;
  _L: {
    const _bind$7 = _M0MP312moonbitstack7moonrpc5proto8WireType10from__code(tag & 7);
    if (_bind$7 === undefined) {
      return new _M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE3Err(new _M0DTPC15error5Error54moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadWireType(tag & 7));
    } else {
      const _Some = _bind$7;
      const _w = _Some;
      w = _w;
      break _L;
    }
  }
  return new _M0DTPC16result6ResultGUiRP312moonbitstack7moonrpc5proto8WireTypeERP312moonbitstack7moonrpc5proto7PbErrorE2Ok({ _0: field, _1: w });
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader13read__fixed32(self) {
  let v;
  _L: {
    const _bind$6 = self.data;
    const _bind$7 = _M0FP312moonbitstack7moonvar5fixed17read__u32_2einner(new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), self.pos, 1);
    if (_bind$7 === undefined) {
      return new _M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated__);
    } else {
      const _Some = _bind$7;
      const _v = _Some;
      v = _v;
      break _L;
    }
  }
  self.pos = self.pos + 4 | 0;
  return new _M0DTPC16result6ResultGjRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(v);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader13read__fixed64(self) {
  let v;
  _L: {
    const _bind$6 = self.data;
    const _bind$7 = _M0FP312moonbitstack7moonvar5fixed17read__u64_2einner(new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), self.pos, 1);
    if (_bind$7 === undefined) {
      return new _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated__);
    } else {
      const _Some = _bind$7;
      const _v = _Some;
      v = _v;
      break _L;
    }
  }
  self.pos = self.pos + 8 | 0;
  return new _M0DTPC16result6ResultGmRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(v);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader16read__len__delim(self) {
  const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader12read__varint(self);
  let _tmp$4;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    _tmp$4 = _ok._0;
  } else {
    return _bind$6;
  }
  const len = Number(BigInt.asIntN(32, _tmp$4)) | 0;
  if (len < 0 || len > (self.data.length - self.pos | 0)) {
    return new _M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error52moonbitstack_2fmoonrpc_2fproto_2ePbError_2eTruncated__);
  }
  const out$2 = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(self.data, self.pos, self.pos + len | 0));
  self.pos = self.pos + len | 0;
  return new _M0DTPC16result6ResultGzRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(out$2);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader12read__string(self) {
  const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader16read__len__delim(self);
  let body;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    body = _ok._0;
  } else {
    return _bind$6;
  }
  let _try_err;
  _L: {
    const _bind$7 = _M0FPC28encoding4utf814decode_2einner(new _M0TPC15bytes9BytesView(body, 0, body.length), false);
    let _tmp$4;
    if (_bind$7.$tag === 1) {
      const _ok = _bind$7;
      _tmp$4 = _ok._0;
    } else {
      const _err = _bind$7;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(_tmp$4);
  }
  return new _M0DTPC16result6ResultGsRP312moonbitstack7moonrpc5proto7PbErrorE3Err(_M0DTPC15error5Error50moonbitstack_2fmoonrpc_2fproto_2ePbError_2eBadUtf8__);
}
function _M0MP312moonbitstack7moonrpc5proto8PbReader4skip(self, wire) {
  switch (wire) {
    case 0: {
      const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader12read__varint(self);
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _ok._0;
      } else {
        return _bind$6;
      }
      break;
    }
    case 1: {
      const _bind$7 = _M0MP312moonbitstack7moonrpc5proto8PbReader13read__fixed64(self);
      if (_bind$7.$tag === 1) {
        const _ok = _bind$7;
        _ok._0;
      } else {
        return _bind$7;
      }
      break;
    }
    case 3: {
      const _bind$8 = _M0MP312moonbitstack7moonrpc5proto8PbReader13read__fixed32(self);
      if (_bind$8.$tag === 1) {
        const _ok = _bind$8;
        _ok._0;
      } else {
        return _bind$8;
      }
      break;
    }
    default: {
      const _bind$9 = _M0MP312moonbitstack7moonrpc5proto8PbReader16read__len__delim(self);
      if (_bind$9.$tag === 1) {
        const _ok = _bind$9;
        _ok._0;
      } else {
        return _bind$9;
      }
    }
  }
  return new _M0DTPC16result6ResultGuRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(undefined);
}
function _M0MP312moonbitstack7moonrpc6stream10RpcContext5empty() {
  return new _M0TP312moonbitstack7moonrpc6stream10RpcContext("", [], undefined, [], [], undefined, []);
}
function _M0MP312moonbitstack7moonrpc6stream10RpcContext4fail(self, code, message) {
  self.status_fail = { _0: code, _1: message };
}
function _M0FP312moonbitstack7moonrpc6stream20parse__grpc__timeout(v) {
  if (v.length < 2) {
    return undefined;
  }
  if ((v.length - 1 | 0) > 8) {
    return undefined;
  }
  const n = new _M0TPB8MutLocalGlE(0n);
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < (v.length - 1 | 0)) {
      const c = i >>> 0 < v.length ? v[i] : $oob();
      if (c < 48 || c > 57) {
        return undefined;
      }
      n.val = BigInt.asUintN(64, BigInt.asUintN(64, n.val * 10n) + BigInt.asUintN(64, BigInt(c - 48 | 0)));
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _tmp$5 = v.length - 1 | 0;
  const _bind$6 = _tmp$5 >>> 0 < v.length ? v[_tmp$5] : $oob();
  let millis;
  switch (_bind$6) {
    case 72: {
      millis = BigInt.asUintN(64, BigInt.asUintN(64, n.val * 3600n) * 1000n);
      break;
    }
    case 77: {
      millis = BigInt.asUintN(64, BigInt.asUintN(64, n.val * 60n) * 1000n);
      break;
    }
    case 83: {
      millis = BigInt.asUintN(64, n.val * 1000n);
      break;
    }
    case 109: {
      millis = n.val;
      break;
    }
    case 117: {
      if (1000n === 0n) {
        $panic();
      }
      millis = BigInt.asUintN(64, BigInt.asIntN(64, n.val) / BigInt.asIntN(64, 1000n));
      break;
    }
    case 110: {
      if (1000000n === 0n) {
        $panic();
      }
      millis = BigInt.asUintN(64, BigInt.asIntN(64, n.val) / BigInt.asIntN(64, 1000000n));
      break;
    }
    default: {
      return undefined;
    }
  }
  return BigInt.asIntN(64, millis) > BigInt.asIntN(64, 2147483647n) ? 2147483647 : Number(BigInt.asIntN(32, millis)) | 0;
}
function _M0IP312moonbitstack7moonrpc6stream11StreamStatePB4Show6output(self, logger) {
  let _tmp$4;
  switch (self) {
    case 0: {
      _tmp$4 = "idle";
      break;
    }
    case 1: {
      _tmp$4 = "reserved(local)";
      break;
    }
    case 2: {
      _tmp$4 = "reserved(remote)";
      break;
    }
    case 3: {
      _tmp$4 = "open";
      break;
    }
    case 4: {
      _tmp$4 = "half-closed(local)";
      break;
    }
    case 5: {
      _tmp$4 = "half-closed(remote)";
      break;
    }
    default: {
      _tmp$4 = "closed";
    }
  }
  logger.method_table.method_0(logger.self, _tmp$4);
}
function _M0IP312moonbitstack7moonrpc6stream11StreamErrorPB4Show6output(self, logger) {
  let m;
  _L: {
    const _InvalidTransition = self;
    const _m = _InvalidTransition._0;
    m = _m;
    break _L;
  }
  logger.method_table.method_0(logger.self, `InvalidTransition(${m})`);
}
function _M0FP312moonbitstack7moonrpc6stream3bad(from, dir, ev) {
  let name;
  switch (ev.$tag) {
    case 0: {
      name = "HEADERS";
      break;
    }
    case 1: {
      name = "DATA";
      break;
    }
    case 2: {
      name = "PUSH_PROMISE";
      break;
    }
    default: {
      name = "RST_STREAM";
    }
  }
  return new _M0DTPC15error5Error65moonbitstack_2fmoonrpc_2fstream_2eStreamError_2eInvalidTransition(`${dir} ${name} not allowed in state ${_M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack7moonrpc6stream11StreamStateE(from)}`);
}
function _M0MP312moonbitstack7moonrpc6stream11StreamState8on__send(self, ev) {
  _L: {
    let end_stream;
    _L$2: {
      let end_stream$2;
      _L$3: {
        let end_stream$3;
        _L$4: {
          let end_stream$4;
          _L$5: {
            switch (self) {
              case 0: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers = ev;
                    const _end_stream = _Headers._0;
                    end_stream$4 = _end_stream;
                    break _L$5;
                  }
                  case 2: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(1);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 1: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$2 = ev;
                    const _end_stream$2 = _Headers$2._0;
                    end_stream$3 = _end_stream$2;
                    break _L$4;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 2: {
                if (ev.$tag === 3) {
                  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                } else {
                  break _L;
                }
              }
              case 3: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$3 = ev;
                    const _end_stream$3 = _Headers$3._0;
                    end_stream$2 = _end_stream$3;
                    break _L$3;
                  }
                  case 1: {
                    const _Data = ev;
                    const _end_stream$4 = _Data._0;
                    end_stream$2 = _end_stream$4;
                    break _L$3;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 5: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$4 = ev;
                    const _end_stream$5 = _Headers$4._0;
                    end_stream = _end_stream$5;
                    break _L$2;
                  }
                  case 1: {
                    const _Data$2 = ev;
                    const _end_stream$6 = _Data$2._0;
                    end_stream = _end_stream$6;
                    break _L$2;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 4: {
                if (ev.$tag === 3) {
                  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                } else {
                  break _L;
                }
              }
              default: {
                break _L;
              }
            }
          }
          return end_stream$4 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(4) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(3);
        }
        return end_stream$3 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(5);
      }
      return end_stream$2 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(4) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(3);
    }
    return end_stream ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(5);
  }
  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE3Err(_M0FP312moonbitstack7moonrpc6stream3bad(self, "sending", ev));
}
function _M0MP312moonbitstack7moonrpc6stream11StreamState8on__recv(self, ev) {
  _L: {
    let end_stream;
    _L$2: {
      let end_stream$2;
      _L$3: {
        let end_stream$3;
        _L$4: {
          let end_stream$4;
          _L$5: {
            switch (self) {
              case 0: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers = ev;
                    const _end_stream = _Headers._0;
                    end_stream$4 = _end_stream;
                    break _L$5;
                  }
                  case 2: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(2);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 2: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$2 = ev;
                    const _end_stream$2 = _Headers$2._0;
                    end_stream$3 = _end_stream$2;
                    break _L$4;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 1: {
                if (ev.$tag === 3) {
                  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                } else {
                  break _L;
                }
              }
              case 3: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$3 = ev;
                    const _end_stream$3 = _Headers$3._0;
                    end_stream$2 = _end_stream$3;
                    break _L$3;
                  }
                  case 1: {
                    const _Data = ev;
                    const _end_stream$4 = _Data._0;
                    end_stream$2 = _end_stream$4;
                    break _L$3;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 4: {
                switch (ev.$tag) {
                  case 0: {
                    const _Headers$4 = ev;
                    const _end_stream$5 = _Headers$4._0;
                    end_stream = _end_stream$5;
                    break _L$2;
                  }
                  case 1: {
                    const _Data$2 = ev;
                    const _end_stream$6 = _Data$2._0;
                    end_stream = _end_stream$6;
                    break _L$2;
                  }
                  case 3: {
                    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                  }
                  default: {
                    break _L;
                  }
                }
              }
              case 5: {
                if (ev.$tag === 3) {
                  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6);
                } else {
                  break _L;
                }
              }
              default: {
                break _L;
              }
            }
          }
          return end_stream$4 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(5) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(3);
        }
        return end_stream$3 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(4);
      }
      return end_stream$2 ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(5) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(3);
    }
    return end_stream ? new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(6) : new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE2Ok(4);
  }
  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP312moonbitstack7moonrpc6stream11StreamErrorE3Err(_M0FP312moonbitstack7moonrpc6stream3bad(self, "receiving", ev));
}
function _M0FP312moonbitstack7moonrpc6stream29stream__is__client__initiated(id) {
  if (id > 0) {
    if (2 === 0) {
      $panic();
    }
    return (id % 2 | 0) === 1;
  } else {
    return false;
  }
}
function _M0MP312moonbitstack7moonrpc6server9SrvStream3new(id, send_window) {
  return new _M0TP312moonbitstack7moonrpc6server9SrvStream(id, 0, _M0MPC16buffer6Buffer14Buffer_2einner(0), _M0MPC16buffer6Buffer14Buffer_2einner(0), 0, [], 0, false, false, false, "", _M0MP312moonbitstack7moonrpc6stream10RpcContext5empty(), undefined, _M0FP312moonbitstack7moonrpc4wire21default__window__size, send_window, $bytes_literal$0, 0, false, false, false, false, false, 200, 0, "", $bytes_literal$0, false, false, false, false, undefined);
}
function _M0MP312moonbitstack7moonrpc6server9SrvStream6retire(self) {
  self.state = 6;
  self.in_headers = false;
  _M0MPC16buffer6Buffer5reset(self.header_block);
  _M0MPC16buffer6Buffer5reset(self.data);
  _M0MPC15array5Array5clearGzE(self.req_msgs);
  self.out = $bytes_literal$0;
  self.out_off = 0;
}
function _M0MP312moonbitstack7moonrpc6server8H2Server3new() {
  const _bind$6 = [];
  const _tmp$4 = _M0MPB3Map3MapGsRP312moonbitstack7moonrpc6stream7HandlerE(new _M0TPB9ArrayViewGUsRP312moonbitstack7moonrpc6stream7HandlerEE(_bind$6, 0, 0), undefined);
  const _tmp$5 = _M0MP312moonbitstack8moonhttp5hpack7Encoder3new(undefined, -1);
  const _tmp$6 = _M0MP312moonbitstack8moonhttp5hpack7Decoder3new(undefined);
  const _bind$7 = [];
  return new _M0TP312moonbitstack7moonrpc6server8H2Server(_tmp$4, _tmp$5, _tmp$6, _M0MPB3Map3MapGiRP312moonbitstack7moonrpc6server9SrvStreamE(new _M0TPB9ArrayViewGUiRP312moonbitstack7moonrpc6server9SrvStreamEE(_bind$7, 0, 0), undefined), [], [], _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire21default__window__size, _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size, _M0FP312moonbitstack7moonrpc6server21default__max__streams, () => 0n, undefined, false, 0, false, undefined);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server8register(self, path, handler) {
  _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, path, new _M0DTP312moonbitstack7moonrpc6stream7Handler5Unary((_ctx, req) => handler(req)));
}
function _M0MP312moonbitstack7moonrpc6server8H2Server17register__handler(self, path, handler) {
  _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, path, handler);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server27register__server__streaming(self, path, handler) {
  _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, path, new _M0DTP312moonbitstack7moonrpc6stream7Handler15ServerStreaming(handler));
}
function _M0MP312moonbitstack7moonrpc6server8H2Server27register__client__streaming(self, path, handler) {
  _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, path, new _M0DTP312moonbitstack7moonrpc6stream7Handler15ClientStreaming(handler));
}
function _M0MP312moonbitstack7moonrpc6server8H2Server14register__bidi(self, path, factory) {
  _M0MPB3Map3setGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, path, new _M0DTP312moonbitstack7moonrpc6stream7Handler4Bidi(factory));
}
function _M0MP312moonbitstack7moonrpc6server8H2Server7preface(self) {
  return [new _M0DTP312moonbitstack8moonhttp5http25Frame8Settings([{ _0: _M0FP312moonbitstack8moonhttp5http222settings__enable__push, _1: 0 }, { _0: _M0FP312moonbitstack8moonhttp5http234settings__max__concurrent__streams, _1: self.max_streams }], false)];
}
function _M0FP312moonbitstack7moonrpc6server20emit__header__frames(stream_id, block, end_stream, max_frame_in) {
  const max_frame = max_frame_in < 1 ? _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size : max_frame_in;
  const frames = [];
  if (block.length <= max_frame) {
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame7Headers(stream_id, block, end_stream, true, undefined, 0));
    return frames;
  }
  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame7Headers(stream_id, _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(block, 0, max_frame)), end_stream, false, undefined, 0));
  const off = new _M0TPB8MutLocalGiE(max_frame);
  while (true) {
    if (off.val < block.length) {
      const n = (block.length - off.val | 0) < max_frame ? block.length - off.val | 0 : max_frame;
      const chunk = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(block, off.val, off.val + n | 0));
      off.val = off.val + n | 0;
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame12Continuation(stream_id, chunk, off.val >= block.length));
      continue;
    } else {
      break;
    }
  }
  return frames;
}
function _M0FP312moonbitstack7moonrpc6server23encode__status__details(code, message, details) {
  const w = _M0MP312moonbitstack7moonrpc5proto8PbWriter3new();
  _M0MP312moonbitstack7moonrpc5proto8PbWriter5int32(w, 1, code);
  _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 2, message);
  const _bind$6 = details.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const d = details[_];
      _M0MP312moonbitstack7moonrpc5proto8PbWriter9message__(w, 3, d);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(w);
}
function _M0FP312moonbitstack7moonrpc6server15percent__encode(msg) {
  const _bind$6 = _M0FP212moonbitstack7moonurl12escape__text(new _M0TPC16string10StringView(msg, 0, msg.length), undefined, new _M0TPC16string10StringView(_M0FP312moonbitstack7moonrpc6server10grpc__safe, 0, _M0FP312moonbitstack7moonrpc6server10grpc__safe.length));
  return _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), false);
}
function _M0FP312moonbitstack7moonrpc6server13header__value(headers, name) {
  const _bind$6 = headers.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const h = headers[_];
      if ($bytes_equal(h.name, name)) {
        return h.value;
      }
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return undefined;
}
function _M0FP312moonbitstack7moonrpc6server12starts__with(b, prefix) {
  if (b.length < prefix.length) {
    return false;
  }
  let _tmp$4 = 0;
  while (true) {
    const i = _tmp$4;
    if (i < prefix.length) {
      if ((i >>> 0 < b.length ? b[i] : $oob()) !== (i >>> 0 < prefix.length ? prefix[i] : $oob())) {
        return false;
      }
      _tmp$4 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return true;
}
function _M0FP312moonbitstack7moonrpc6server15request__reject(headers) {
  _L: {
    _L$2: {
      let ct;
      _L$3: {
        const _bind$6 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$1);
        if (_bind$6 === undefined) {
          break _L$2;
        } else {
          const _Some = _bind$6;
          const _ct = _Some;
          if (_M0FP312moonbitstack7moonrpc6server12starts__with(_ct, $bytes_literal$16)) {
            ct = _ct;
            break _L$3;
          } else {
            break _L$2;
          }
        }
      }
      break _L;
    }
    return { _0: 415, _1: _M0MP312moonbitstack7moonrpc4wire6Status4code(3), _2: "content-type is not application/grpc" };
  }
  _L$2: {
    _L$3: {
      let m;
      _L$4: {
        const _bind$6 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$9);
        if (_bind$6 === undefined) {
          break _L$3;
        } else {
          const _Some = _bind$6;
          const _m = _Some;
          if ($bytes_equal(_m, $bytes_literal$10)) {
            m = _m;
            break _L$4;
          } else {
            break _L$3;
          }
        }
      }
      break _L$2;
    }
    return { _0: 405, _1: _M0MP312moonbitstack7moonrpc4wire6Status4code(13), _2: ":method is not POST" };
  }
  _L$3: {
    _L$4: {
      let te;
      _L$5: {
        const _bind$6 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$2);
        if (_bind$6 === undefined) {
          break _L$4;
        } else {
          const _Some = _bind$6;
          const _te = _Some;
          if ($bytes_equal(_te, $bytes_literal$15)) {
            te = _te;
            break _L$5;
          } else {
            break _L$4;
          }
        }
      }
      break _L$3;
    }
    return { _0: 400, _1: _M0MP312moonbitstack7moonrpc4wire6Status4code(13), _2: "te: trailers is missing" };
  }
  return undefined;
}
function _M0FP312moonbitstack7moonrpc6server15drain__messages(s) {
  const all = _M0MPC16buffer6Buffer9to__bytes(s.data);
  const n = all.length;
  const off = new _M0TPB8MutLocalGiE(s.req_off);
  while (true) {
    if ((n - off.val | 0) >= 5) {
      const _tmp$4 = off.val;
      const compressed = (_tmp$4 >>> 0 < all.length ? all[_tmp$4] : $oob()) !== 0;
      const len = _M0MPC16option6Option6unwrapGiE(_M0FP312moonbitstack7moonrpc4wire20message__len_2einner(new _M0TPC15bytes9BytesView(all, 0, all.length), off.val));
      if (len < 0 || len > _M0FP312moonbitstack7moonrpc4wire18max__message__size) {
        s.oversize = true;
        break;
      }
      if ((n - off.val | 0) < (5 + len | 0)) {
        break;
      }
      if (compressed) {
        const body = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(all, off.val + 5 | 0, (off.val + 5 | 0) + len | 0));
        if ($bytes_equal(s.req_encoding, $bytes_literal$17)) {
          let plain;
          let _try_err;
          _L: {
            _L$2: {
              const _bind$6 = _M0FP312moonbitstack7moonzip4gzip14gunzip_2einner(new _M0TPC15bytes9BytesView(body, 0, body.length), true, true, true, undefined);
              if (_bind$6.$tag === 1) {
                const _ok = _bind$6;
                plain = _ok._0;
              } else {
                const _err = _bind$6;
                _try_err = _err._0;
                break _L$2;
              }
              break _L;
            }
            plain = undefined;
          }
          let m;
          _L$2: {
            _L$3: {
              if (plain === undefined) {
                s.compressed_unsupported = true;
              } else {
                const _Some = plain;
                const _m = _Some;
                m = _m;
                break _L$3;
              }
              break _L$2;
            }
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(s.req_msgs, m);
          }
        } else {
          s.compressed_unsupported = true;
        }
      } else {
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(s.req_msgs, _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(all, off.val + 5 | 0, (off.val + 5 | 0) + len | 0)));
      }
      off.val = (off.val + 5 | 0) + len | 0;
      continue;
    } else {
      break;
    }
  }
  s.req_off = off.val;
}
function _M0MP312moonbitstack7moonrpc6server8H2Server6stream(self, id) {
  const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, id);
  if (_bind$6 === undefined) {
    const s = _M0MP312moonbitstack7moonrpc6server9SrvStream3new(id, self.remote_initial_window);
    _M0MPB3Map3setGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, id, s);
    return s;
  } else {
    const _Some = _bind$6;
    const _s = _Some;
    return _s;
  }
}
function _M0MP312moonbitstack7moonrpc6server8H2Server14apply__setting(self, id, value) {
  if (id === _M0FP312moonbitstack8moonhttp5http231settings__initial__window__size) {
    if (value < 0) {
      return undefined;
    }
    const delta = value - self.remote_initial_window | 0;
    self.remote_initial_window = value;
    const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams);
    while (true) {
      let s;
      _L: {
        const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6server9SrvStreamE(_it);
        if (_bind$6 === undefined) {
          return;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          const _s = _x._1;
          s = _s;
          break _L;
        }
      }
      s.send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(s.send_window, delta);
      continue;
    }
  } else {
    if (id === _M0FP312moonbitstack8moonhttp5http226settings__max__frame__size) {
      self.remote_max_frame = value < _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size ? _M0FP312moonbitstack7moonrpc4wire25default__max__frame__size : value > 16777215 ? 16777215 : value;
      return;
    } else {
      if (id === _M0FP312moonbitstack8moonhttp5http229settings__header__table__size) {
        if (value >= 0) {
          _M0MP312moonbitstack8moonhttp5hpack5Table6resize(self.encoder.table, value);
          return;
        } else {
          return;
        }
      } else {
        return;
      }
    }
  }
}
function _M0MP312moonbitstack7moonrpc6server8H2Server12credit__conn(self) {
  const _tmp$4 = self.conn_recv_window;
  if (2 === 0) {
    $panic();
  }
  if (_tmp$4 < (_M0FP312moonbitstack7moonrpc4wire21default__window__size / 2 | 0)) {
    const inc = _M0FP312moonbitstack7moonrpc4wire21default__window__size - self.conn_recv_window | 0;
    self.conn_recv_window = self.conn_recv_window + inc | 0;
    return [new _M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate(0, inc)];
  }
  return [];
}
function _M0MP312moonbitstack7moonrpc6server8H2Server9replenish(self, s) {
  const frames = _M0MP312moonbitstack7moonrpc6server8H2Server12credit__conn(self);
  if (2 === 0) {
    $panic();
  }
  const threshold = _M0FP312moonbitstack7moonrpc4wire21default__window__size / 2 | 0;
  if (s.recv_window < threshold) {
    const inc = _M0FP312moonbitstack7moonrpc4wire21default__window__size - s.recv_window | 0;
    s.recv_window = s.recv_window + inc | 0;
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame12WindowUpdate(s.id, inc));
  }
  return frames;
}
function _M0FP312moonbitstack7moonrpc6server13fault__frames(fault, last_stream) {
  let code;
  let why;
  _L: {
    let id;
    let code$2;
    _L$2: {
      if (fault.$tag === 22) {
        const _StreamFault = fault;
        const _id = _StreamFault._0;
        const _code = _StreamFault._1;
        id = _id;
        code$2 = _code;
        break _L$2;
      } else {
        const _ConnFault = fault;
        const _code = _ConnFault._0;
        const _why = _ConnFault._1;
        code = _code;
        why = _why;
        break _L;
      }
    }
    return [new _M0DTP312moonbitstack8moonhttp5http25Frame9RstStream(id, code$2)];
  }
  return [new _M0DTP312moonbitstack8moonhttp5http25Frame6GoAway(last_stream, code, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(why, 0, why.length), false))];
}
function _M0MP312moonbitstack7moonrpc6server8H2Server6report(self, f) {
  const frames = [];
  let id;
  _L: {
    _L$2: {
      if (f.$tag === 21) {
        self.closing = true;
      } else {
        const _StreamFault = f;
        const _id = _StreamFault._0;
        id = _id;
        break _L$2;
      }
      break _L;
    }
    let s;
    _L$3: {
      _L$4: {
        const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, id);
        if (_bind$6 === undefined) {
        } else {
          const _Some = _bind$6;
          const _s = _Some;
          s = _s;
          break _L$4;
        }
        break _L$3;
      }
      _M0MP312moonbitstack7moonrpc6server9SrvStream6retire(s);
    }
    const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server12credit__conn(self);
    const _bind$7 = _bind$6.length;
    let _tmp$4 = 0;
    while (true) {
      const _ = _tmp$4;
      if (_ < _bind$7) {
        const g = _bind$6[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, g);
        _tmp$4 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
  }
  const _bind$6 = _M0FP312moonbitstack7moonrpc6server13fault__frames(f, self.last_client_stream);
  const _bind$7 = _bind$6.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$7) {
      const g = _bind$6[_];
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, g);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return frames;
}
function _M0FP312moonbitstack7moonrpc6server17transition__fault(id, state, why) {
  if (state === 0) {
    return new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, why);
  } else {
    return new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(id, _M0FP312moonbitstack8moonhttp5http221error__stream__closed, why);
  }
}
function _M0FP312moonbitstack7moonrpc6server11recv__event(s, ev) {
  let _try_err;
  _L: {
    const _bind$6 = _M0MP312moonbitstack7moonrpc6stream11StreamState8on__recv(s.state, ev);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
  }
  let m;
  _L$2: {
    const _InvalidTransition = _try_err;
    const _m = _InvalidTransition._0;
    m = _m;
    break _L$2;
  }
  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE3Err(_M0FP312moonbitstack7moonrpc6server17transition__fault(s.id, s.state, m));
}
function _M0FP312moonbitstack7moonrpc6server17window__overflows(cur, inc) {
  return BigInt.asIntN(64, BigInt.asUintN(64, BigInt.asUintN(64, BigInt(cur)) + BigInt.asUintN(64, BigInt(inc)))) > BigInt.asIntN(64, 2147483647n);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server15active__streams(self) {
  const n = new _M0TPB8MutLocalGiE(0);
  const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams);
  while (true) {
    let _id;
    let s;
    _L: {
      const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6server9SrvStreamE(_it);
      if (_bind$6 === undefined) {
        break;
      } else {
        const _Some = _bind$6;
        const _x = _Some;
        const __id = _x._0;
        const _s = _x._1;
        _id = __id;
        s = _s;
        break _L;
      }
    }
    _L$2: {
      _L$3: {
        const _bind$6 = s.state;
        switch (_bind$6) {
          case 3: {
            break _L$3;
          }
          case 4: {
            break _L$3;
          }
          case 5: {
            break _L$3;
          }
        }
        break _L$2;
      }
      n.val = n.val + 1 | 0;
    }
    continue;
  }
  return n.val;
}
function _M0MP312moonbitstack7moonrpc6server8H2Server7enqueue(self, s, msg) {
  s.out = _M0IPC15bytes5BytesPB3Add3add(s.out, _M0FP312moonbitstack7moonrpc4wire23encode__message_2einner(msg, false));
  s.started_response = true;
}
function _M0FP312moonbitstack7moonrpc6server11send__event(s, ev) {
  let _try_err;
  _L: {
    const _bind$6 = _M0MP312moonbitstack7moonrpc6stream11StreamState8on__send(s.state, ev);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
    return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
  }
  let m;
  _L$2: {
    const _InvalidTransition = _try_err;
    const _m = _InvalidTransition._0;
    m = _m;
    break _L$2;
  }
  return new _M0DTPC16result6ResultGRP312moonbitstack7moonrpc6stream11StreamStateRP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__internal__error, m));
}
function _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s) {
  const frames = [];
  if (s.trailers_only) {
    if (!s.trailers_sent) {
      const _bind$6 = _M0MPC13int3Int18to__string_2einner(s.http_status, 10);
      const _tmp$4 = new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$18, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), false));
      const _tmp$5 = new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$1, $bytes_literal$16);
      const _tmp$6 = new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$5, $bytes_literal$21);
      const _bind$7 = _M0MPC13int3Int18to__string_2einner(s.status_code, 10);
      const tr = [_tmp$4, _tmp$5, _tmp$6, new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$19, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$7, 0, _bind$7.length), false)), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$20, _M0FP312moonbitstack7moonrpc6server15percent__encode(s.status_message))];
      if (s.status_code !== 0) {
        const _bind$8 = _M0FP312moonbitstack7moonrpc6server23encode__status__details(s.status_code, s.status_message, s.ctx.error_details);
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(tr, new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$22, _M0FP312moonbitstack8moonbase6base6413encode__bytes(new _M0TPC15bytes9BytesView(_bind$8, 0, _bind$8.length), undefined, -1)));
      }
      const _bind$8 = s.ctx.resp_trailers;
      const _bind$9 = _bind$8.length;
      let _tmp$7 = 0;
      while (true) {
        const _ = _tmp$7;
        if (_ < _bind$9) {
          const h = _bind$8[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(tr, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire25metadata__value__to__wire(h.name, h.value)));
          _tmp$7 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      const block = _M0MP312moonbitstack8moonhttp5hpack7Encoder6encode(self.encoder, new _M0TPB9ArrayViewGRP312moonbitstack8moonhttp6header6HeaderE(tr, 0, tr.length));
      const _bind$10 = _M0FP312moonbitstack7moonrpc6server20emit__header__frames(s.id, block, true, self.remote_max_frame);
      const _bind$11 = _bind$10.length;
      let _tmp$8 = 0;
      while (true) {
        const _ = _tmp$8;
        if (_ < _bind$11) {
          const f = _bind$10[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
          _tmp$8 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      const _bind$12 = _M0FP312moonbitstack7moonrpc6server11send__event(s, new _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers(true));
      let _tmp$9;
      if (_bind$12.$tag === 1) {
        const _ok = _bind$12;
        _tmp$9 = _ok._0;
      } else {
        return _bind$12;
      }
      s.state = _tmp$9;
      s.trailers_sent = true;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(frames);
  }
  if (s.started_response && !s.headers_sent) {
    const headers = [new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$18, $bytes_literal$23), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$1, $bytes_literal$16), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$4, $bytes_literal$24), new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$5, $bytes_literal$21)];
    const _bind$6 = s.ctx.resp_headers;
    const _bind$7 = _bind$6.length;
    let _tmp$4 = 0;
    while (true) {
      const _ = _tmp$4;
      if (_ < _bind$7) {
        const h = _bind$6[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(headers, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire25metadata__value__to__wire(h.name, h.value)));
        _tmp$4 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const block = _M0MP312moonbitstack8moonhttp5hpack7Encoder6encode(self.encoder, new _M0TPB9ArrayViewGRP312moonbitstack8moonhttp6header6HeaderE(headers, 0, headers.length));
    const _bind$8 = _M0FP312moonbitstack7moonrpc6server20emit__header__frames(s.id, block, false, self.remote_max_frame);
    const _bind$9 = _bind$8.length;
    let _tmp$5 = 0;
    while (true) {
      const _ = _tmp$5;
      if (_ < _bind$9) {
        const f = _bind$8[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
        _tmp$5 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const _bind$10 = _M0FP312moonbitstack7moonrpc6server11send__event(s, new _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers(false));
    let _tmp$6;
    if (_bind$10.$tag === 1) {
      const _ok = _bind$10;
      _tmp$6 = _ok._0;
    } else {
      return _bind$10;
    }
    s.state = _tmp$6;
    s.headers_sent = true;
  }
  while (true) {
    if (s.out_off < s.out.length) {
      const remaining = s.out.length - s.out_off | 0;
      const budget = _M0FPC13cmp7minimumGiE(_M0FPC13cmp7minimumGiE(self.conn_send_window, s.send_window), self.remote_max_frame);
      if (budget <= 0) {
        break;
      }
      const n = remaining < budget ? remaining : budget;
      const chunk = _M0MPC15bytes9BytesView9to__owned(_M0MPC15bytes5Bytes21clamped__view_2einner(s.out, s.out_off, s.out_off + n | 0));
      s.out_off = s.out_off + n | 0;
      self.conn_send_window = self.conn_send_window - n | 0;
      s.send_window = s.send_window - n | 0;
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame4Data(s.id, chunk, false, 0));
      continue;
    } else {
      break;
    }
  }
  if (s.response_ended && (s.out_off >= s.out.length && (s.headers_sent && !s.trailers_sent))) {
    const _bind$6 = _M0MPC13int3Int18to__string_2einner(s.status_code, 10);
    const trailers = [new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$19, _M0FPC28encoding4utf814encode_2einner(new _M0TPC16string10StringView(_bind$6, 0, _bind$6.length), false))];
    if (s.status_code !== 0 && _M0IP016_24default__implPB2Eq10not__equalGsE(s.status_message, "")) {
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(trailers, new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$20, _M0FP312moonbitstack7moonrpc6server15percent__encode(s.status_message)));
    }
    if (s.status_code !== 0) {
      const _bind$7 = _M0FP312moonbitstack7moonrpc6server23encode__status__details(s.status_code, s.status_message, s.ctx.error_details);
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(trailers, new _M0TP312moonbitstack8moonhttp6header6Header($bytes_literal$22, _M0FP312moonbitstack8moonbase6base6413encode__bytes(new _M0TPC15bytes9BytesView(_bind$7, 0, _bind$7.length), undefined, -1)));
    }
    const _bind$7 = s.ctx.resp_trailers;
    const _bind$8 = _bind$7.length;
    let _tmp$4 = 0;
    while (true) {
      const _ = _tmp$4;
      if (_ < _bind$8) {
        const h = _bind$7[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(trailers, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire25metadata__value__to__wire(h.name, h.value)));
        _tmp$4 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const block = _M0MP312moonbitstack8moonhttp5hpack7Encoder6encode(self.encoder, new _M0TPB9ArrayViewGRP312moonbitstack8moonhttp6header6HeaderE(trailers, 0, trailers.length));
    const _bind$9 = _M0FP312moonbitstack7moonrpc6server20emit__header__frames(s.id, block, true, self.remote_max_frame);
    const _bind$10 = _bind$9.length;
    let _tmp$5 = 0;
    while (true) {
      const _ = _tmp$5;
      if (_ < _bind$10) {
        const f = _bind$9[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
        _tmp$5 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    const _bind$11 = _M0FP312moonbitstack7moonrpc6server11send__event(s, new _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers(true));
    let _tmp$6;
    if (_bind$11.$tag === 1) {
      const _ok = _bind$11;
      _tmp$6 = _ok._0;
    } else {
      return _bind$11;
    }
    s.state = _tmp$6;
    s.trailers_sent = true;
    _M0MPC16buffer6Buffer5reset(s.header_block);
    _M0MPC16buffer6Buffer5reset(s.data);
    _M0MPC15array5Array5clearGzE(s.req_msgs);
    s.out = $bytes_literal$0;
    s.out_off = 0;
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(frames);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server6expire(self, s) {
  s.out = $bytes_literal$0;
  s.out_off = 0;
  s.status_code = _M0MP312moonbitstack7moonrpc4wire6Status4code(4);
  s.status_message = "deadline exceeded";
  if (!s.headers_sent) {
    s.trailers_only = true;
  }
  s.started = true;
  s.finalized = true;
  s.response_ended = true;
  const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s);
  let frames;
  if (_bind$6.$tag === 1) {
    const _ok = _bind$6;
    frames = _ok._0;
  } else {
    return _bind$6;
  }
  if (!s.end_stream_recv) {
    _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, new _M0DTP312moonbitstack8moonhttp5http25Frame9RstStream(s.id, _M0FP312moonbitstack8moonhttp5http216error__no__error));
    _M0MP312moonbitstack7moonrpc6server9SrvStream6retire(s);
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(frames);
}
function _M0FP312moonbitstack7moonrpc6server15compose__stream(chain, base) {
  const h = new _M0TPB8MutLocalGWRP312moonbitstack7moonrpc6stream10RpcContextzERPB5ArrayGzEE(base);
  let _tmp$4 = chain.length - 1 | 0;
  while (true) {
    const i = _tmp$4;
    if (i >= 0) {
      const ic = _M0MPC15array5Array2atGsE(chain, i);
      const next = h.val;
      h.val = (ctx, req) => ic(ctx, req, next);
      _tmp$4 = i - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return h.val;
}
function _M0FP312moonbitstack7moonrpc6server14compose__unary(chain, base) {
  const h = new _M0TPB8MutLocalGWRP312moonbitstack7moonrpc6stream10RpcContextzEzE(base);
  let _tmp$4 = chain.length - 1 | 0;
  while (true) {
    const i = _tmp$4;
    if (i >= 0) {
      const ic = _M0MPC15array5Array2atGsE(chain, i);
      const next = h.val;
      h.val = (ctx, req) => ic(ctx, req, next);
      _tmp$4 = i - 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return h.val;
}
function _M0MP312moonbitstack7moonrpc6server8H2Server7deliver(self, s, replies) {
  let code;
  let message;
  _L: {
    const _bind$6 = s.ctx.status_fail;
    if (_bind$6 === undefined) {
      const _bind$7 = replies.length;
      let _tmp$4 = 0;
      while (true) {
        const _ = _tmp$4;
        if (_ < _bind$7) {
          const r = replies[_];
          _M0MP312moonbitstack7moonrpc6server8H2Server7enqueue(self, s, r);
          _tmp$4 = _ + 1 | 0;
          continue;
        } else {
          return;
        }
      }
    } else {
      const _Some = _bind$6;
      const _x = _Some;
      const _code = _x._0;
      const _message = _x._1;
      code = _code;
      message = _message;
      break _L;
    }
  }
  s.status_code = code;
  s.status_message = message;
  if (!s.started_response) {
    s.trailers_only = true;
    return;
  } else {
    return;
  }
}
function _M0MP312moonbitstack7moonrpc6server8H2Server8finalize(self, s) {
  let h;
  _L: {
    _L$2: {
      let h$2;
      _L$3: {
        _L$4: {
          let h$3;
          _L$5: {
            _L$6: {
              const _bind$6 = _M0MPB3Map3getGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, s.path);
              if (_bind$6 === undefined) {
              } else {
                const _Some = _bind$6;
                const _x = _Some;
                switch (_x.$tag) {
                  case 0: {
                    const _Unary = _x;
                    const _h = _Unary._0;
                    h$3 = _h;
                    break _L$6;
                  }
                  case 1: {
                    const _ServerStreaming = _x;
                    const _h$2 = _ServerStreaming._0;
                    h$2 = _h$2;
                    break _L$4;
                  }
                  case 2: {
                    const _ClientStreaming = _x;
                    const _h$3 = _ClientStreaming._0;
                    h = _h$3;
                    break _L$2;
                  }
                  default: {
                    let bh;
                    _L$7: {
                      _L$8: {
                        const _bind$7 = s.bidi;
                        if (_bind$7 === undefined) {
                        } else {
                          const _Some$2 = _bind$7;
                          const _bh = _Some$2;
                          bh = _bh;
                          break _L$8;
                        }
                        break _L$7;
                      }
                      const _func = bh.on_end;
                      _M0MP312moonbitstack7moonrpc6server8H2Server7deliver(self, s, _func());
                    }
                  }
                }
              }
              break _L$5;
            }
            const msg = s.req_msgs.length > 0 ? _M0MPC15array5Array2atGsE(s.req_msgs, 0) : $bytes_literal$0;
            const effective = _M0FP312moonbitstack7moonrpc6server14compose__unary(self.unary_interceptors, h$3);
            _M0MP312moonbitstack7moonrpc6server8H2Server7deliver(self, s, [effective(s.ctx, msg)]);
          }
          break _L$3;
        }
        const msg = s.req_msgs.length > 0 ? _M0MPC15array5Array2atGsE(s.req_msgs, 0) : $bytes_literal$0;
        const effective = _M0FP312moonbitstack7moonrpc6server15compose__stream(self.stream_interceptors, h$2);
        _M0MP312moonbitstack7moonrpc6server8H2Server7deliver(self, s, effective(s.ctx, msg));
      }
      break _L;
    }
    _M0MP312moonbitstack7moonrpc6server8H2Server7deliver(self, s, [h(s.ctx, s.req_msgs)]);
  }
  s.started_response = true;
  s.response_ended = true;
}
function _M0MP312moonbitstack7moonrpc6server8H2Server14past__deadline(self, s) {
  let t;
  _L: {
    const _bind$6 = s.deadline_at;
    if (_bind$6 === undefined) {
      return false;
    } else {
      const _Some = _bind$6;
      const _t = _Some;
      t = _t;
      break _L;
    }
  }
  const _func = self.clock;
  return BigInt.asIntN(64, _func()) >= BigInt.asIntN(64, t);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server7advance(self, s) {
  if (!s.headers_complete) {
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]);
  }
  if (!s.started) {
    s.started = true;
    let factory;
    _L: {
      _L$2: {
        const _bind$6 = _M0MPB3Map3getGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, s.path);
        if (_bind$6 === undefined) {
          s.trailers_only = true;
          s.status_code = _M0MP312moonbitstack7moonrpc4wire6Status4code(12);
          s.status_message = "method not found";
          s.response_ended = true;
        } else {
          const _Some = _bind$6;
          const _x = _Some;
          if (_x.$tag === 3) {
            const _Bidi = _x;
            const _factory = _Bidi._0;
            factory = _factory;
            break _L$2;
          }
        }
        break _L;
      }
      s.bidi = factory(s.ctx);
    }
  }
  if (!s.trailers_sent && _M0MP312moonbitstack7moonrpc6server8H2Server14past__deadline(self, s)) {
    const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server6expire(self, s);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      return _bind$6;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
  }
  if (!s.trailers_only) {
    _M0FP312moonbitstack7moonrpc6server15drain__messages(s);
    if (s.compressed_unsupported && !s.response_ended) {
      s.trailers_only = true;
      s.status_code = _M0MP312moonbitstack7moonrpc4wire6Status4code(12);
      s.status_message = "grpc-encoding not supported; server accepts identity, gzip";
      s.response_ended = true;
      const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s);
      let _tmp$4;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _tmp$4 = _ok._0;
      } else {
        return _bind$6;
      }
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
    }
    if (s.oversize && !s.response_ended) {
      s.trailers_only = true;
      s.status_code = _M0MP312moonbitstack7moonrpc4wire6Status4code(8);
      s.status_message = "received message larger than max";
      s.response_ended = true;
      const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s);
      let _tmp$4;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _tmp$4 = _ok._0;
      } else {
        return _bind$6;
      }
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
    }
    const _bind$6 = _M0MPB3Map3getGsRP312moonbitstack7moonrpc6stream7HandlerE(self.handlers, s.path);
    if (_bind$6 === undefined) {
    } else {
      const _Some = _bind$6;
      const _x = _Some;
      if (_x.$tag === 3) {
        let bh;
        _L: {
          _L$2: {
            const _bind$7 = s.bidi;
            if (_bind$7 === undefined) {
            } else {
              const _Some$2 = _bind$7;
              const _bh = _Some$2;
              bh = _bh;
              break _L$2;
            }
            break _L;
          }
          while (true) {
            if (s.bidi_processed < s.req_msgs.length) {
              const m = _M0MPC15array5Array2atGsE(s.req_msgs, s.bidi_processed);
              s.bidi_processed = s.bidi_processed + 1 | 0;
              const _func = bh.on_message;
              const _bind$7 = _func(m);
              const _bind$8 = _bind$7.length;
              let _tmp$4 = 0;
              while (true) {
                const _ = _tmp$4;
                if (_ < _bind$8) {
                  const r = _bind$7[_];
                  _M0MP312moonbitstack7moonrpc6server8H2Server7enqueue(self, s, r);
                  _tmp$4 = _ + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
              continue;
            } else {
              break;
            }
          }
        }
      }
    }
    if (s.end_stream_recv && !s.finalized) {
      s.finalized = true;
      _M0MP312moonbitstack7moonrpc6server8H2Server8finalize(self, s);
      if (_M0MP312moonbitstack7moonrpc6server8H2Server14past__deadline(self, s)) {
        const _bind$7 = _M0MP312moonbitstack7moonrpc6server8H2Server6expire(self, s);
        let _tmp$4;
        if (_bind$7.$tag === 1) {
          const _ok = _bind$7;
          _tmp$4 = _ok._0;
        } else {
          return _bind$7;
        }
        return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
      }
    }
  }
  return _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server17complete__headers(self, s) {
  let headers;
  let _try_err;
  _L: {
    _L$2: {
      const _tmp$4 = self.decoder;
      const _bind$6 = _M0MPC16buffer6Buffer9to__bytes(s.header_block);
      const _bind$7 = _M0MP312moonbitstack8moonhttp5hpack7Decoder6decode(_tmp$4, new _M0TPC15bytes9BytesView(_bind$6, 0, _bind$6.length), undefined);
      if (_bind$7.$tag === 1) {
        const _ok = _bind$7;
        headers = _ok._0;
      } else {
        const _err = _bind$7;
        _try_err = _err._0;
        break _L$2;
      }
      break _L;
    }
    const e = _try_err;
    return new _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http225error__compression__error, _M0IP016_24default__implPB4Show10to__stringGRP312moonbitstack8moonhttp5hpack7RefusedE(e)));
  }
  let _tmp$4;
  let p;
  _L$2: {
    _L$3: {
      const _bind$6 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$13);
      if (_bind$6 === undefined) {
        _tmp$4 = "";
      } else {
        const _Some = _bind$6;
        const _p = _Some;
        p = _p;
        break _L$3;
      }
      break _L$2;
    }
    _tmp$4 = _M0FPC28encoding4utf821decode__lossy_2einner(new _M0TPC15bytes9BytesView(p, 0, p.length), false);
  }
  s.path = _tmp$4;
  s.headers_complete = true;
  s.in_headers = false;
  let code;
  let http;
  let why;
  _L$3: {
    _L$4: {
      const _bind$6 = _M0FP312moonbitstack7moonrpc6server15request__reject(headers);
      if (_bind$6 === undefined) {
      } else {
        const _Some = _bind$6;
        const _x = _Some;
        const _http = _x._0;
        const _code = _x._1;
        const _why = _x._2;
        code = _code;
        http = _http;
        why = _why;
        break _L$4;
      }
      break _L$3;
    }
    s.http_status = http;
    s.status_code = code;
    s.status_message = why;
    s.trailers_only = true;
    s.started = true;
    s.response_ended = true;
    return new _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(undefined);
  }
  const metadata = [];
  const _bind$6 = headers.length;
  let _tmp$5 = 0;
  while (true) {
    const _ = _tmp$5;
    if (_ < _bind$6) {
      const h = headers[_];
      if (!_M0FP412moonbitstack7moonrpc8internal2h220is__reserved__header(h.name)) {
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(metadata, new _M0TP312moonbitstack8moonhttp6header6Header(h.name, _M0FP312moonbitstack7moonrpc4wire27metadata__value__from__wire(h.name, h.value)));
      }
      _tmp$5 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  let deadline;
  let v;
  _L$4: {
    _L$5: {
      const _bind$7 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$3);
      if (_bind$7 === undefined) {
        deadline = undefined;
      } else {
        const _Some = _bind$7;
        const _v = _Some;
        v = _v;
        break _L$5;
      }
      break _L$4;
    }
    deadline = _M0FP312moonbitstack7moonrpc6stream20parse__grpc__timeout(v);
  }
  let _tmp$6;
  let d;
  _L$5: {
    _L$6: {
      if (deadline === undefined) {
        _tmp$6 = undefined;
      } else {
        const _Some = deadline;
        const _d = _Some;
        d = _d;
        break _L$6;
      }
      break _L$5;
    }
    const _func = self.clock;
    _tmp$6 = BigInt.asUintN(64, _func() + BigInt.asUintN(64, BigInt(d)));
  }
  s.deadline_at = _tmp$6;
  let _tmp$7;
  const _bind$7 = _M0FP312moonbitstack7moonrpc6server13header__value(headers, $bytes_literal$4);
  if (_bind$7 === undefined) {
    _tmp$7 = $bytes_literal$0;
  } else {
    const _Some = _bind$7;
    const _v = _Some;
    _tmp$7 = _v;
  }
  s.req_encoding = _tmp$7;
  s.ctx = new _M0TP312moonbitstack7moonrpc6stream10RpcContext(s.path, metadata, deadline, [], [], undefined, []);
  return new _M0DTPC16result6ResultGuRP412moonbitstack7moonrpc8internal2h25FaultE2Ok(undefined);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server5flush(self, s) {
  if (!s.trailers_sent && _M0MP312moonbitstack7moonrpc6server8H2Server14past__deadline(self, s)) {
    const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server6expire(self, s);
    let _tmp$4;
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _tmp$4 = _ok._0;
    } else {
      return _bind$6;
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(_tmp$4);
  }
  return _M0MP312moonbitstack7moonrpc6server8H2Server7produce(self, s);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server9pump__all(self) {
  const frames = [];
  const _it = _M0MPB3Map5iter2GiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams);
  while (true) {
    let s;
    _L: {
      const _bind$6 = _M0MPB5Iter24nextGiRP312moonbitstack7moonrpc6server9SrvStreamE(_it);
      if (_bind$6 === undefined) {
        break;
      } else {
        const _Some = _bind$6;
        const _x = _Some;
        const _s = _x._1;
        s = _s;
        break _L;
      }
    }
    let _tmp$4;
    if (s.started) {
      let _tmp$5;
      if (!s.trailers_sent) {
        const _bind$6 = s.state;
        let _tmp$6;
        if (_bind$6 === 6) {
          _tmp$6 = true;
        } else {
          _tmp$6 = false;
        }
        _tmp$5 = !_tmp$6;
      } else {
        _tmp$5 = false;
      }
      _tmp$4 = _tmp$5;
    } else {
      _tmp$4 = false;
    }
    if (_tmp$4) {
      const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server5flush(self, s);
      let _bind$7;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _bind$7 = _ok._0;
      } else {
        return _bind$6;
      }
      const _bind$8 = _bind$7.length;
      let _tmp$5 = 0;
      while (true) {
        const _ = _tmp$5;
        if (_ < _bind$8) {
          const f = _bind$7[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
          _tmp$5 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    }
    continue;
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(frames);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server4step(self, frame) {
  let id;
  _L: {
    _L$2: {
      const _bind$6 = self.continuing;
      if (_bind$6 === undefined) {
      } else {
        const _Some = _bind$6;
        const _id = _Some;
        id = _id;
        break _L$2;
      }
      break _L;
    }
    let continues;
    let stream_id;
    _L$3: {
      _L$4: {
        if (frame.$tag === 9) {
          const _Continuation = frame;
          const _stream_id = _Continuation._0;
          stream_id = _stream_id;
          break _L$4;
        } else {
          continues = false;
        }
        break _L$3;
      }
      continues = stream_id === id;
    }
    if (!continues) {
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "frame interleaved into an open field block"));
    }
  }
  _L$2: {
    let stream_id;
    _L$3: {
      let end_stream;
      let stream_id$2;
      let data;
      let padding;
      _L$4: {
        let fragment;
        let stream_id$3;
        let end_headers;
        _L$5: {
          let end_stream$2;
          let stream_id$4;
          let fragment$2;
          let end_headers$2;
          _L$6: {
            let stream_id$5;
            let increment;
            _L$7: {
              let payload;
              let ack;
              _L$8: {
                let params;
                let ack$2;
                _L$9: {
                  switch (frame.$tag) {
                    case 4: {
                      const _Settings = frame;
                      const _params = _Settings._0;
                      const _ack = _Settings._1;
                      params = _params;
                      ack$2 = _ack;
                      break _L$9;
                    }
                    case 6: {
                      const _Ping = frame;
                      const _payload = _Ping._0;
                      const _ack$2 = _Ping._1;
                      payload = _payload;
                      ack = _ack$2;
                      break _L$8;
                    }
                    case 8: {
                      const _WindowUpdate = frame;
                      const _stream_id = _WindowUpdate._0;
                      const _increment = _WindowUpdate._1;
                      stream_id$5 = _stream_id;
                      increment = _increment;
                      break _L$7;
                    }
                    case 1: {
                      const _Headers = frame;
                      const _stream_id$2 = _Headers._0;
                      const _fragment = _Headers._1;
                      const _end_stream = _Headers._2;
                      const _end_headers = _Headers._3;
                      end_stream$2 = _end_stream;
                      stream_id$4 = _stream_id$2;
                      fragment$2 = _fragment;
                      end_headers$2 = _end_headers;
                      break _L$6;
                    }
                    case 9: {
                      const _Continuation = frame;
                      const _stream_id$3 = _Continuation._0;
                      const _fragment$2 = _Continuation._1;
                      const _end_headers$2 = _Continuation._2;
                      fragment = _fragment$2;
                      stream_id$3 = _stream_id$3;
                      end_headers = _end_headers$2;
                      break _L$5;
                    }
                    case 0: {
                      const _Data = frame;
                      const _stream_id$4 = _Data._0;
                      const _data = _Data._1;
                      const _end_stream$2 = _Data._2;
                      const _padding = _Data._3;
                      end_stream = _end_stream$2;
                      stream_id$2 = _stream_id$4;
                      data = _data;
                      padding = _padding;
                      break _L$4;
                    }
                    case 3: {
                      const _RstStream = frame;
                      const _stream_id$5 = _RstStream._0;
                      stream_id = _stream_id$5;
                      break _L$3;
                    }
                    case 7: {
                      self.goaway_received = true;
                      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]);
                    }
                    case 2: {
                      break _L$2;
                    }
                    case 5: {
                      break _L$2;
                    }
                    default: {
                      break _L$2;
                    }
                  }
                }
                if (ack$2) {
                  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]);
                } else {
                  const _bind$6 = params.length;
                  let _tmp$4 = 0;
                  while (true) {
                    const _ = _tmp$4;
                    if (_ < _bind$6) {
                      const p = params[_];
                      _M0MP312moonbitstack7moonrpc6server8H2Server14apply__setting(self, p._0, p._1);
                      _tmp$4 = _ + 1 | 0;
                      continue;
                    } else {
                      break;
                    }
                  }
                  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([new _M0DTP312moonbitstack8moonhttp5http25Frame8Settings([], true)]);
                }
              }
              return ack ? new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]) : new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([new _M0DTP312moonbitstack8moonhttp5http25Frame4Ping(payload, true)]);
            }
            if (increment === 0) {
              const why = "WINDOW_UPDATE with a zero increment";
              if (stream_id$5 === 0) {
                return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, why));
              }
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(stream_id$5, _M0FP312moonbitstack8moonhttp5http222error__protocol__error, why));
            }
            if (stream_id$5 === 0) {
              if (_M0FP312moonbitstack7moonrpc6server17window__overflows(self.conn_send_window, increment)) {
                return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http227error__flow__control__error, "connection window over 2^31-1"));
              }
              self.conn_send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(self.conn_send_window, increment);
            } else {
              const s = _M0MP312moonbitstack7moonrpc6server8H2Server6stream(self, stream_id$5);
              if (_M0FP312moonbitstack7moonrpc6server17window__overflows(s.send_window, increment)) {
                return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(stream_id$5, _M0FP312moonbitstack8moonhttp5http227error__flow__control__error, "stream window over 2^31-1"));
              }
              s.send_window = _M0FP412moonbitstack7moonrpc8internal2h211add__window(s.send_window, increment);
            }
            return _M0MP312moonbitstack7moonrpc6server8H2Server9pump__all(self);
          }
          if (stream_id$4 === 0) {
            return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "HEADERS on stream 0"));
          }
          const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, stream_id$4);
          if (_bind$6 === undefined) {
            if (!_M0FP312moonbitstack7moonrpc6stream29stream__is__client__initiated(stream_id$4) || stream_id$4 <= self.last_client_stream) {
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, `invalid client stream id ${_M0MPC13int3Int18to__string_2einner(stream_id$4, 10)}`));
            }
            let last;
            _L$7: {
              _L$8: {
                const _bind$7 = self.drained;
                if (_bind$7 === undefined) {
                } else {
                  const _Some = _bind$7;
                  const _last = _Some;
                  if (stream_id$4 > _last) {
                    last = _last;
                    break _L$8;
                  }
                }
                break _L$7;
              }
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(stream_id$4, _M0FP312moonbitstack8moonhttp5http222error__refused__stream, "server is draining"));
            }
            if (_M0MP312moonbitstack7moonrpc6server8H2Server15active__streams(self) >= self.max_streams) {
              return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(stream_id$4, _M0FP312moonbitstack8moonhttp5http222error__refused__stream, "over SETTINGS_MAX_CONCURRENT_STREAMS"));
            }
            self.last_client_stream = stream_id$4;
          }
          const s = _M0MP312moonbitstack7moonrpc6server8H2Server6stream(self, stream_id$4);
          const _bind$7 = _M0FP312moonbitstack7moonrpc6server11recv__event(s, new _M0DTP312moonbitstack7moonrpc6stream11StreamEvent7Headers(end_stream$2));
          let _tmp$4;
          if (_bind$7.$tag === 1) {
            const _ok = _bind$7;
            _tmp$4 = _ok._0;
          } else {
            return _bind$7;
          }
          s.state = _tmp$4;
          _M0MPC16buffer6Buffer12write__bytes(s.header_block, new _M0TPC15bytes9BytesView(fragment$2, 0, fragment$2.length));
          const _bind$8 = _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(s.header_block);
          if (_bind$8.$tag === 1) {
            const _ok = _bind$8;
            _ok._0;
          } else {
            return _bind$8;
          }
          if (end_stream$2) {
            s.end_stream_recv = true;
          }
          if (end_headers$2) {
            const _bind$9 = _M0MP312moonbitstack7moonrpc6server8H2Server17complete__headers(self, s);
            if (_bind$9.$tag === 1) {
              const _ok = _bind$9;
              _ok._0;
            } else {
              return _bind$9;
            }
          } else {
            s.in_headers = true;
            self.continuing = stream_id$4;
          }
          return _M0MP312moonbitstack7moonrpc6server8H2Server7advance(self, s);
        }
        if (stream_id$3 === 0) {
          return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "CONTINUATION on stream 0"));
        }
        let s;
        _L$6: {
          _L$7: {
            const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, stream_id$3);
            if (_bind$6 === undefined) {
              break _L$7;
            } else {
              const _Some = _bind$6;
              const _s = _Some;
              if (_s.in_headers) {
                s = _s;
              } else {
                break _L$7;
              }
            }
            break _L$6;
          }
          return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "CONTINUATION with no field block in progress"));
        }
        _M0MPC16buffer6Buffer12write__bytes(s.header_block, new _M0TPC15bytes9BytesView(fragment, 0, fragment.length));
        const _bind$6 = _M0FP412moonbitstack7moonrpc8internal2h219guard__header__size(s.header_block);
        if (_bind$6.$tag === 1) {
          const _ok = _bind$6;
          _ok._0;
        } else {
          return _bind$6;
        }
        if (end_headers) {
          self.continuing = undefined;
          const _bind$7 = _M0MP312moonbitstack7moonrpc6server8H2Server17complete__headers(self, s);
          if (_bind$7.$tag === 1) {
            const _ok = _bind$7;
            _ok._0;
          } else {
            return _bind$7;
          }
        }
        return _M0MP312moonbitstack7moonrpc6server8H2Server7advance(self, s);
      }
      if (stream_id$2 === 0) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "DATA on stream 0"));
      }
      const flow_len = (data.length + padding | 0) + (padding > 0 ? 1 : 0) | 0;
      self.conn_recv_window = self.conn_recv_window - flow_len | 0;
      if (self.conn_recv_window < 0) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http227error__flow__control__error, "DATA past the connection receive window"));
      }
      const s = _M0MP312moonbitstack7moonrpc6server8H2Server6stream(self, stream_id$2);
      const _bind$6 = _M0FP312moonbitstack7moonrpc6server11recv__event(s, new _M0DTP312moonbitstack7moonrpc6stream11StreamEvent4Data(end_stream));
      let _tmp$4;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _tmp$4 = _ok._0;
      } else {
        return _bind$6;
      }
      s.state = _tmp$4;
      s.recv_window = s.recv_window - flow_len | 0;
      if (s.recv_window < 0) {
        return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error60moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eStreamFault(stream_id$2, _M0FP312moonbitstack8moonhttp5http227error__flow__control__error, "DATA past the stream receive window"));
      }
      _M0MPC16buffer6Buffer12write__bytes(s.data, new _M0TPC15bytes9BytesView(data, 0, data.length));
      if (end_stream) {
        s.end_stream_recv = true;
      }
      const frames = _M0MP312moonbitstack7moonrpc6server8H2Server9replenish(self, s);
      const _bind$7 = _M0MP312moonbitstack7moonrpc6server8H2Server7advance(self, s);
      let _bind$8;
      if (_bind$7.$tag === 1) {
        const _ok = _bind$7;
        _bind$8 = _ok._0;
      } else {
        return _bind$7;
      }
      const _bind$9 = _bind$8.length;
      let _tmp$5 = 0;
      while (true) {
        const _ = _tmp$5;
        if (_ < _bind$9) {
          const f = _bind$8[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(frames, f);
          _tmp$5 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok(frames);
    }
    if (stream_id === 0) {
      return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE3Err(new _M0DTPC15error5Error58moonbitstack_2fmoonrpc_2finternal_2fh2_2eFault_2eConnFault(_M0FP312moonbitstack8moonhttp5http222error__protocol__error, "RST_STREAM on stream 0"));
    }
    let s;
    _L$4: {
      _L$5: {
        const _bind$6 = _M0MPB3Map3getGiRP312moonbitstack7moonrpc6server9SrvStreamE(self.streams, stream_id);
        if (_bind$6 === undefined) {
        } else {
          const _Some = _bind$6;
          const _s = _Some;
          s = _s;
          break _L$5;
        }
        break _L$4;
      }
      _M0MP312moonbitstack7moonrpc6server9SrvStream6retire(s);
    }
    return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]);
  }
  return new _M0DTPC16result6ResultGRPB5ArrayGRP312moonbitstack8moonhttp5http25FrameERP412moonbitstack7moonrpc8internal2h25FaultE2Ok([]);
}
function _M0MP312moonbitstack7moonrpc6server8H2Server4feed(self, frame) {
  if (self.closing) {
    return [];
  }
  let _try_err;
  _L: {
    const _bind$6 = _M0MP312moonbitstack7moonrpc6server8H2Server4step(self, frame);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      return _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
  }
  const f = _try_err;
  return _M0MP312moonbitstack7moonrpc6server8H2Server6report(self, f);
}
function _M0FP312moonbitstack7moonrpc7service10status__of(e) {
  let e$2;
  _L: {
    let status;
    let message;
    _L$2: {
      if (e.$tag === 15) {
        const _StatusError = e;
        const _status = _StatusError._0;
        const _message = _StatusError._1;
        status = _status;
        message = _message;
        break _L$2;
      } else {
        e$2 = e;
        break _L;
      }
    }
    return { _0: _M0MP312moonbitstack7moonrpc4wire6Status4code(status), _1: message };
  }
  return { _0: _M0MP312moonbitstack7moonrpc4wire6Status4code(2), _1: _M0FP15Error10to__string(e$2) };
}
function _M0FP312moonbitstack7moonrpc7service7requestGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetE(ctx, body) {
  let _try_err;
  _L: {
    const _bind$6 = _M0IP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetP312moonbitstack7moonrpc5proto7Message6decode(body);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      return _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
  }
  const e = _try_err;
  const _tmp$4 = _M0MP312moonbitstack7moonrpc4wire6Status4code(13);
  const _string_builder = _M0MPB13StringBuilder21StringBuilder_2einner(35);
  _M0IPB13StringBuilderPB6Logger13write__string(_string_builder, "grpc: error unmarshalling request: ");
  _M0MPB13StringBuilder13write__objectGRP312moonbitstack7moonrpc5proto7PbErrorE(_string_builder, e);
  _M0MP312moonbitstack7moonrpc6stream10RpcContext4fail(ctx, _tmp$4, _M0MPB13StringBuilder10to__string(_string_builder));
  return undefined;
}
function _M0FP312moonbitstack7moonrpc7service5unaryGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetE(f) {
  return new _M0DTP312moonbitstack7moonrpc6stream7Handler5Unary((ctx, body) => {
    let input;
    _L: {
      const _bind$6 = _M0FP312moonbitstack7moonrpc7service7requestGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetE(ctx, body);
      if (_bind$6 === undefined) {
        return $bytes_literal$0;
      } else {
        const _Some = _bind$6;
        const _input = _Some;
        input = _input;
        break _L;
      }
    }
    let _try_err;
    _L$2: {
      const _bind$6 = f(ctx, input);
      let _tmp$4;
      if (_bind$6.$tag === 1) {
        const _ok = _bind$6;
        _tmp$4 = _ok._0;
      } else {
        const _err = _bind$6;
        _try_err = _err._0;
        break _L$2;
      }
      return _M0IP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetP312moonbitstack7moonrpc5proto7Message6encode(_tmp$4);
    }
    const e = _try_err;
    let code;
    let message;
    _L$3: {
      const _bind$6 = _M0FP312moonbitstack7moonrpc7service10status__of(e);
      const _code = _bind$6._0;
      const _message = _bind$6._1;
      code = _code;
      message = _message;
      break _L$3;
    }
    _M0MP312moonbitstack7moonrpc6stream10RpcContext4fail(ctx, code, message);
    return $bytes_literal$0;
  });
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5ascii(bs) {
  const buf = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  const _bind$6 = bs.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const b = bs[_];
      _M0IPB13StringBuilderPB6Logger11write__char(buf, b & 255);
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPB13StringBuilder10to__string(buf);
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6digits(n) {
  switch (n) {
    case 0: {
      return "0";
    }
    case 1: {
      return "1";
    }
    case 2: {
      return "2";
    }
    case 3: {
      return "3";
    }
    case 4: {
      return "4";
    }
    case 5: {
      return "5";
    }
    case 6: {
      return "6";
    }
    case 7: {
      return "7";
    }
    case 8: {
      return "8";
    }
    case 9: {
      return "9";
    }
    case 10: {
      return "a";
    }
    case 11: {
      return "b";
    }
    case 12: {
      return "c";
    }
    case 13: {
      return "d";
    }
    case 14: {
      return "e";
    }
    default: {
      return "f";
    }
  }
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo4hex2(b) {
  const n = b & 255;
  return `${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6digits(n >> 4 & 15)}${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6digits(n & 15)}`;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo7to__hex(bs) {
  const buf = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  const _bind$6 = bs.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const b = bs[_];
      _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo4hex2(b));
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPB13StringBuilder10to__string(buf);
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6hexval(c) {
  return c >= 48 && c <= 57 ? c - 48 | 0 : c >= 97 && c <= 102 ? (c - 97 | 0) + 10 | 0 : c >= 65 && c <= 70 ? (c - 65 | 0) + 10 | 0 : 0;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo9from__hex(s) {
  const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
  const arr = _M0MPC16string6String9to__array(s);
  const i = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if ((i.val + 1 | 0) < arr.length) {
      const hi = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6hexval(_M0MPC15array5Array2atGcE(arr, i.val));
      const lo = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo6hexval(_M0MPC15array5Array2atGcE(arr, i.val + 1 | 0));
      _M0MPC16buffer6Buffer11write__byte(buf, (hi << 4 | lo) & 255);
      i.val = i.val + 2 | 0;
      continue;
    } else {
      break;
    }
  }
  return _M0MPC16buffer6Buffer9to__bytes(buf);
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10split__bar(s) {
  const out$2 = [];
  const buf = new _M0TPB8MutLocalGRPB13StringBuilderE(_M0MPB13StringBuilder21StringBuilder_2einner(0));
  const _bind$6 = s.length;
  let _tmp$4 = 0;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$6) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$7 = s.charCodeAt(_string_index);
        if (_bind$7 >= 55296 && _bind$7 <= 56319 && (_string_index + 1 | 0) < _bind$6) {
          const _bind$8 = s.charCodeAt(_string_index + 1 | 0);
          if (_bind$8 >= 56320 && _bind$8 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$7 - 55296 | 0, 1024) | 0) + _bind$8 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
          break _L;
        }
      }
      const _next_string_index = _decoded_next_string_index;
      const c = _decoded_char;
      if (c === 124) {
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out$2, _M0MPB13StringBuilder10to__string(buf.val));
        buf.val = _M0MPB13StringBuilder21StringBuilder_2einner(0);
      } else {
        _M0IPB13StringBuilderPB6Logger11write__char(buf.val, c);
      }
      _tmp$4 = _next_string_index;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out$2, _M0MPB13StringBuilder10to__string(buf.val));
  return out$2;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12split__comma(s) {
  const out$2 = [];
  const buf = new _M0TPB8MutLocalGRPB13StringBuilderE(_M0MPB13StringBuilder21StringBuilder_2einner(0));
  const _bind$6 = s.length;
  let _tmp$4 = 0;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$6) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$7 = s.charCodeAt(_string_index);
        if (_bind$7 >= 55296 && _bind$7 <= 56319 && (_string_index + 1 | 0) < _bind$6) {
          const _bind$8 = s.charCodeAt(_string_index + 1 | 0);
          if (_bind$8 >= 56320 && _bind$8 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$7 - 55296 | 0, 1024) | 0) + _bind$8 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
          break _L;
        }
      }
      const _next_string_index = _decoded_next_string_index;
      const c = _decoded_char;
      if (c === 44) {
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out$2, _M0MPB13StringBuilder10to__string(buf.val));
        buf.val = _M0MPB13StringBuilder21StringBuilder_2einner(0);
      } else {
        _M0IPB13StringBuilderPB6Logger11write__char(buf.val, c);
      }
      _tmp$4 = _next_string_index;
      continue;
    } else {
      break;
    }
  }
  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(out$2, _M0MPB13StringBuilder10to__string(buf.val));
  return out$2;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10parse__int(s) {
  const n = new _M0TPB8MutLocalGiE(0);
  const neg = new _M0TPB8MutLocalGbE(false);
  const started = new _M0TPB8MutLocalGbE(false);
  const _bind$6 = s.length;
  let _tmp$4 = 0;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$6) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$7 = s.charCodeAt(_string_index);
        if (_bind$7 >= 55296 && _bind$7 <= 56319 && (_string_index + 1 | 0) < _bind$6) {
          const _bind$8 = s.charCodeAt(_string_index + 1 | 0);
          if (_bind$8 >= 56320 && _bind$8 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$7 - 55296 | 0, 1024) | 0) + _bind$8 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
          break _L;
        }
      }
      const _next_string_index = _decoded_next_string_index;
      const c = _decoded_char;
      if (c === 45 && !started.val) {
        neg.val = true;
      } else {
        if (c >= 48 && c <= 57) {
          started.val = true;
          n.val = (Math.imul(n.val, 10) | 0) + (c - 48 | 0) | 0;
        } else {
          break;
        }
      }
      _tmp$4 = _next_string_index;
      continue;
    } else {
      break;
    }
  }
  return neg.val ? -n.val | 0 : n.val;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12json__escape(s) {
  const buf = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  const _bind$6 = s.length;
  let _tmp$4 = 0;
  while (true) {
    const _string_index = _tmp$4;
    if (_string_index < _bind$6) {
      let _decoded_next_string_index;
      let _decoded_char;
      _L: {
        const _bind$7 = s.charCodeAt(_string_index);
        if (_bind$7 >= 55296 && _bind$7 <= 56319 && (_string_index + 1 | 0) < _bind$6) {
          const _bind$8 = s.charCodeAt(_string_index + 1 | 0);
          if (_bind$8 >= 56320 && _bind$8 <= 57343) {
            _decoded_next_string_index = _string_index + 2 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char((((Math.imul(_bind$7 - 55296 | 0, 1024) | 0) + _bind$8 | 0) - 56320 | 0) + 65536 | 0);
            break _L;
          } else {
            _decoded_next_string_index = _string_index + 1 | 0;
            _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
            break _L;
          }
        } else {
          _decoded_next_string_index = _string_index + 1 | 0;
          _decoded_char = _M0MPC13int3Int16unsafe__to__char(_bind$7);
          break _L;
        }
      }
      const _next_string_index = _decoded_next_string_index;
      const c = _decoded_char;
      if (c === 34) {
        _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\\"");
      } else {
        if (c === 92) {
          _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\\\");
        } else {
          if (c === 10) {
            _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\n");
          } else {
            if (c === 13) {
              _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\r");
            } else {
              if (c === 9) {
                _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\t");
              } else {
                if (c < 32) {
                  _M0IPB13StringBuilderPB6Logger13write__string(buf, "\\u00");
                  _M0IPB13StringBuilderPB6Logger13write__string(buf, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo4hex2(c & 255));
                } else {
                  _M0IPB13StringBuilderPB6Logger11write__char(buf, c);
                }
              }
            }
          }
        }
      }
      _tmp$4 = _next_string_index;
      continue;
    } else {
      break;
    }
  }
  return _M0MPB13StringBuilder10to__string(buf);
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo21demo__encode__message(arg) {
  const parts = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10split__bar(arg);
  const name = parts.length > 0 ? _M0MPC15array5Array2atGsE(parts, 0) : "";
  const count_s = parts.length > 1 ? _M0MPC15array5Array2atGsE(parts, 1) : "0";
  const blob_h = parts.length > 2 ? _M0MPC15array5Array2atGsE(parts, 2) : "";
  const tags_c = parts.length > 3 ? _M0MPC15array5Array2atGsE(parts, 3) : "";
  const count = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10parse__int(count_s);
  const blob = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo9from__hex(blob_h);
  const tags = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12split__comma(tags_c);
  const w = _M0MP312moonbitstack7moonrpc5proto8PbWriter3new();
  if (_M0IP016_24default__implPB2Eq10not__equalGsE(name, "")) {
    _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 1, name);
  }
  if (count !== 0) {
    _M0MP312moonbitstack7moonrpc5proto8PbWriter5int32(w, 2, count);
  }
  if (blob.length > 0) {
    _M0MP312moonbitstack7moonrpc5proto8PbWriter7bytes__(w, 3, blob);
  }
  const _bind$6 = tags.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$6) {
      const t = tags[_];
      if (_M0IP016_24default__implPB2Eq10not__equalGsE(t, "")) {
        _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 4, t);
      }
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const bytes = _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(w);
  const fields = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(fields, "[");
  const first = new _M0TPB8MutLocalGbE(true);
  const emit = (f, wire, tag, label, value) => {
    if (!first.val) {
      _M0IPB13StringBuilderPB6Logger13write__string(fields, ",");
    }
    first.val = false;
    _M0IPB13StringBuilderPB6Logger13write__string(fields, `{\"f\":${_M0MPC13int3Int18to__string_2einner(f, 10)},\"wire\":\"${wire}\",\"tag\":${_M0MPC13int3Int18to__string_2einner(tag, 10)},\"name\":\"${label}\",\"value\":\"${value}\"}`);
  };
  if (_M0IP016_24default__implPB2Eq10not__equalGsE(name, "")) {
    emit(1, "LengthDelim", 10, "name", name);
  }
  if (count !== 0) {
    emit(2, "Varint", 16, "count", count_s);
  }
  if (blob.length > 0) {
    emit(3, "LengthDelim", 26, "blob", blob_h);
  }
  const _bind$7 = tags.length;
  let _tmp$5 = 0;
  while (true) {
    const _ = _tmp$5;
    if (_ < _bind$7) {
      const t = tags[_];
      if (_M0IP016_24default__implPB2Eq10not__equalGsE(t, "")) {
        emit(4, "LengthDelim", 34, "tags", t);
      }
      _tmp$5 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0IPB13StringBuilderPB6Logger13write__string(fields, "]");
  return `{\"hex\":\"${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo7to__hex(bytes)}\",\"fields\":${_M0MPB13StringBuilder10to__string(fields)}}`;
}
function _M0IP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetP312moonbitstack7moonrpc5proto7Message6encode(self) {
  const w = _M0MP312moonbitstack7moonrpc5proto8PbWriter3new();
  if (_M0IP016_24default__implPB2Eq10not__equalGsE(self.text, "")) {
    _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 1, self.text);
  }
  return _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(w);
}
function _M0IP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetP312moonbitstack7moonrpc5proto7Message6decode(b) {
  const r = _M0MP312moonbitstack7moonrpc5proto8PbReader3new(b);
  const text = new _M0TPB8MutLocalGsE("");
  while (true) {
    if (!_M0MP312moonbitstack7moonrpc5proto8PbReader3eof(r)) {
      let wire;
      _L: {
        _L$2: {
          const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader9read__tag(r);
          let _bind$7;
          if (_bind$6.$tag === 1) {
            const _ok = _bind$6;
            _bind$7 = _ok._0;
          } else {
            return _bind$6;
          }
          const _x = _bind$7._0;
          if (_x === 1) {
            const _x$2 = _bind$7._1;
            if (_x$2 === 2) {
              const _bind$8 = _M0MP312moonbitstack7moonrpc5proto8PbReader12read__string(r);
              let _tmp$4;
              if (_bind$8.$tag === 1) {
                const _ok = _bind$8;
                _tmp$4 = _ok._0;
              } else {
                return _bind$8;
              }
              text.val = _tmp$4;
            } else {
              wire = _x$2;
              break _L$2;
            }
          } else {
            const _wire = _bind$7._1;
            wire = _wire;
            break _L$2;
          }
          break _L;
        }
        const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader4skip(r, wire);
        if (_bind$6.$tag === 1) {
          const _ok = _bind$6;
          _ok._0;
        } else {
          return _bind$6;
        }
      }
      continue;
    } else {
      break;
    }
  }
  return new _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc5proto7PbErrorE2Ok(new _M0TP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5Greet(text.val));
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10hello__req(name) {
  const w = _M0MP312moonbitstack7moonrpc5proto8PbWriter3new();
  _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 1, name);
  return _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(w);
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12read__field1(msg) {
  const r = _M0MP312moonbitstack7moonrpc5proto8PbReader3new(msg);
  let _try_err;
  _L: {
    const _bind$6 = _M0MP312moonbitstack7moonrpc5proto8PbReader9read__tag(r);
    if (_bind$6.$tag === 1) {
      const _ok = _bind$6;
      _ok._0;
    } else {
      const _err = _bind$6;
      _try_err = _err._0;
      break _L;
    }
    const _bind$7 = _M0MP312moonbitstack7moonrpc5proto8PbReader12read__string(r);
    if (_bind$7.$tag === 1) {
      const _ok = _bind$7;
      return _ok._0;
    } else {
      const _err = _bind$7;
      _try_err = _err._0;
      break _L;
    }
  }
  return "";
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo13fail__handler(_ctx, _req) {
  return new _M0DTPC16result6ResultGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP312moonbitstack7moonrpc4wire11StatusErrorE3Err(new _M0DTPC15error5Error57moonbitstack_2fmoonrpc_2fwire_2eStatusError_2eStatusError(5, "no such word"));
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__info(f) {
  let stream_id;
  _L: {
    let stream_id$2;
    _L$2: {
      let stream_id$3;
      _L$3: {
        let stream_id$4;
        _L$4: {
          let stream_id$5;
          _L$5: {
            let stream_id$6;
            let end_stream;
            _L$6: {
              let stream_id$7;
              let end_stream$2;
              _L$7: {
                switch (f.$tag) {
                  case 1: {
                    const _Headers = f;
                    const _stream_id = _Headers._0;
                    const _end_stream = _Headers._2;
                    stream_id$7 = _stream_id;
                    end_stream$2 = _end_stream;
                    break _L$7;
                  }
                  case 0: {
                    const _Data = f;
                    const _stream_id$2 = _Data._0;
                    const _end_stream$2 = _Data._2;
                    stream_id$6 = _stream_id$2;
                    end_stream = _end_stream$2;
                    break _L$6;
                  }
                  case 2: {
                    const _Priority = f;
                    const _stream_id$3 = _Priority._0;
                    stream_id$5 = _stream_id$3;
                    break _L$5;
                  }
                  case 3: {
                    const _RstStream = f;
                    const _stream_id$4 = _RstStream._0;
                    stream_id$4 = _stream_id$4;
                    break _L$4;
                  }
                  case 5: {
                    const _PushPromise = f;
                    const _stream_id$5 = _PushPromise._0;
                    stream_id$3 = _stream_id$5;
                    break _L$3;
                  }
                  case 8: {
                    const _WindowUpdate = f;
                    const _stream_id$6 = _WindowUpdate._0;
                    stream_id$2 = _stream_id$6;
                    break _L$2;
                  }
                  case 9: {
                    const _Continuation = f;
                    const _stream_id$7 = _Continuation._0;
                    stream_id = _stream_id$7;
                    break _L;
                  }
                  default: {
                    return { _0: 0, _1: false };
                  }
                }
              }
              return { _0: stream_id$7, _1: end_stream$2 };
            }
            return { _0: stream_id$6, _1: end_stream };
          }
          return { _0: stream_id$5, _1: false };
        }
        return { _0: stream_id$4, _1: false };
      }
      return { _0: stream_id$3, _1: false };
    }
    return { _0: stream_id$2, _1: false };
  }
  return { _0: stream_id, _1: false };
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, dir) {
  let sid;
  let es;
  _L: {
    const _bind$6 = _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__info(f);
    const _sid = _bind$6._0;
    const _es = _bind$6._1;
    sid = _sid;
    es = _es;
    break _L;
  }
  return `{\"d\":\"${dir}\",\"c\":${_M0MPC13int3Int18to__string_2einner(_M0MP312moonbitstack8moonhttp5http25Frame4code(f), 10)},\"s\":${_M0MPC13int3Int18to__string_2einner(sid, 10)},\"es\":${es ? "true" : "false"},\"h\":\"${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo7to__hex(_M0MP312moonbitstack8moonhttp5http25Frame6encode(f))}\"}`;
}
function _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo9demo__run(kind) {
  const server = _M0MP312moonbitstack7moonrpc6server8H2Server3new();
  _M0MP312moonbitstack7moonrpc6server8H2Server8register(server, "/demo.Greeter/SayHello", (req) => {
    const w = _M0MP312moonbitstack7moonrpc5proto8PbWriter3new();
    _M0MP312moonbitstack7moonrpc5proto8PbWriter8string__(w, 1, `hello, ${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12read__field1(req)}`);
    return _M0MP312moonbitstack7moonrpc5proto8PbWriter9to__bytes(w);
  });
  _M0MP312moonbitstack7moonrpc6server8H2Server17register__handler(server, "/demo.Greeter/Fail", _M0FP312moonbitstack7moonrpc7service5unaryGRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetRP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5GreetE(_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo13fail__handler));
  _M0MP312moonbitstack7moonrpc6server8H2Server27register__server__streaming(server, "/demo.Counter/Up", (_ctx, _req) => [$bytes_literal$25, $bytes_literal$26, $bytes_literal$27]);
  _M0MP312moonbitstack7moonrpc6server8H2Server27register__client__streaming(server, "/demo.Sum/Add", (_ctx, msgs) => {
    const buf = _M0MPC16buffer6Buffer14Buffer_2einner(0);
    _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView($bytes_literal$28, 0, 3));
    const _bind$6 = msgs.length;
    let _tmp$4 = 0;
    while (true) {
      const _ = _tmp$4;
      if (_ < _bind$6) {
        const m = msgs[_];
        _M0MPC16buffer6Buffer11write__byte(buf, 47);
        _M0MPC16buffer6Buffer12write__bytes(buf, new _M0TPC15bytes9BytesView(m, 0, m.length));
        _tmp$4 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
    return _M0MPC16buffer6Buffer9to__bytes(buf);
  });
  _M0MP312moonbitstack7moonrpc6server8H2Server14register__bidi(server, "/demo.Chat/Talk", (_ctx) => new _M0TP312moonbitstack7moonrpc6stream11BidiHandler((m) => [_M0IPC15bytes5BytesPB3Add3add(m, $bytes_literal$29)], () => []));
  const client = _M0MP312moonbitstack7moonrpc6client8H2Client3new();
  const to_server = [];
  const to_client = [];
  const fj = [];
  const _bind$6 = _M0MP312moonbitstack7moonrpc6client8H2Client7preface(client);
  const _bind$7 = _bind$6.length;
  let _tmp$4 = 0;
  while (true) {
    const _ = _tmp$4;
    if (_ < _bind$7) {
      const f = _bind$6[_];
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
      _tmp$4 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const _bind$8 = _M0MP312moonbitstack7moonrpc6server8H2Server7preface(server);
  const _bind$9 = _bind$8.length;
  let _tmp$5 = 0;
  while (true) {
    const _ = _tmp$5;
    if (_ < _bind$9) {
      const f = _bind$8[_];
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_client, f);
      _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "S"));
      _tmp$5 = _ + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  const id = new _M0TPB8MutLocalGiE(0);
  if (kind === "server") {
    id.val = _M0MP312moonbitstack7moonrpc6client8H2Client4open(client, "/demo.Counter/Up", _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None__, undefined, undefined);
    const _bind$10 = _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(client, id.val, $bytes_literal$30, true);
    const _bind$11 = _bind$10.length;
    let _tmp$6 = 0;
    while (true) {
      const _ = _tmp$6;
      if (_ < _bind$11) {
        const f = _bind$10[_];
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
        _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
        _tmp$6 = _ + 1 | 0;
        continue;
      } else {
        break;
      }
    }
  } else {
    if (kind === "client") {
      id.val = _M0MP312moonbitstack7moonrpc6client8H2Client4open(client, "/demo.Sum/Add", _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None__, undefined, undefined);
      const _bind$10 = _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(client, id.val, $bytes_literal$31, false);
      const _bind$11 = _bind$10.length;
      let _tmp$6 = 0;
      while (true) {
        const _ = _tmp$6;
        if (_ < _bind$11) {
          const f = _bind$10[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
          _tmp$6 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      const _bind$12 = _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(client, id.val, $bytes_literal$32, false);
      const _bind$13 = _bind$12.length;
      let _tmp$7 = 0;
      while (true) {
        const _ = _tmp$7;
        if (_ < _bind$13) {
          const f = _bind$12[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
          _tmp$7 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
      const _bind$14 = _M0MP312moonbitstack7moonrpc6client8H2Client11close__send(client, id.val);
      const _bind$15 = _bind$14.length;
      let _tmp$8 = 0;
      while (true) {
        const _ = _tmp$8;
        if (_ < _bind$15) {
          const f = _bind$14[_];
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
          _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
          _tmp$8 = _ + 1 | 0;
          continue;
        } else {
          break;
        }
      }
    } else {
      if (kind === "bidi") {
        id.val = _M0MP312moonbitstack7moonrpc6client8H2Client4open(client, "/demo.Chat/Talk", _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None__, undefined, undefined);
        const _bind$10 = _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(client, id.val, $bytes_literal$33, false);
        const _bind$11 = _bind$10.length;
        let _tmp$6 = 0;
        while (true) {
          const _ = _tmp$6;
          if (_ < _bind$11) {
            const f = _bind$10[_];
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
            _tmp$6 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        const _bind$12 = _M0MP312moonbitstack7moonrpc6client8H2Client12send_2einner(client, id.val, $bytes_literal$34, false);
        const _bind$13 = _bind$12.length;
        let _tmp$7 = 0;
        while (true) {
          const _ = _tmp$7;
          if (_ < _bind$13) {
            const f = _bind$12[_];
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
            _tmp$7 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
        const _bind$14 = _M0MP312moonbitstack7moonrpc6client8H2Client11close__send(client, id.val);
        const _bind$15 = _bind$14.length;
        let _tmp$8 = 0;
        while (true) {
          const _ = _tmp$8;
          if (_ < _bind$15) {
            const f = _bind$14[_];
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
            _tmp$8 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      } else {
        const path = kind === "error" ? "/demo.Greeter/Fail" : "/demo.Greeter/SayHello";
        let i;
        let frames;
        _L: {
          const _bind$10 = _M0MP312moonbitstack7moonrpc6client8H2Client5unary(client, path, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo10hello__req("world"), _M0DTPC16option6OptionGRPB5ArrayGRP312moonbitstack8moonhttp6header6HeaderEE4None__, undefined, undefined);
          const _i = _bind$10._0;
          const _frames = _bind$10._1;
          i = _i;
          frames = _frames;
          break _L;
        }
        id.val = i;
        const _bind$10 = frames.length;
        let _tmp$6 = 0;
        while (true) {
          const _ = _tmp$6;
          if (_ < _bind$10) {
            const f = frames[_];
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, f);
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(f, "C"));
            _tmp$6 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      }
    }
  }
  const si = new _M0TPB8MutLocalGiE(0);
  const ci = new _M0TPB8MutLocalGiE(0);
  const steps = new _M0TPB8MutLocalGiE(0);
  while (true) {
    if (!_M0MP312moonbitstack7moonrpc6client8H2Client8is__done(client, id.val) && steps.val < 100000) {
      steps.val = steps.val + 1 | 0;
      if (si.val < to_server.length) {
        const f = _M0MPC15array5Array2atGsE(to_server, si.val);
        si.val = si.val + 1 | 0;
        const _bind$10 = _M0MP312moonbitstack7moonrpc6server8H2Server4feed(server, f);
        const _bind$11 = _bind$10.length;
        let _tmp$6 = 0;
        while (true) {
          const _ = _tmp$6;
          if (_ < _bind$11) {
            const r = _bind$10[_];
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_client, r);
            _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(r, "S"));
            _tmp$6 = _ + 1 | 0;
            continue;
          } else {
            break;
          }
        }
      } else {
        if (ci.val < to_client.length) {
          const f = _M0MPC15array5Array2atGsE(to_client, ci.val);
          ci.val = ci.val + 1 | 0;
          let _try_err;
          _L: {
            _L$2: {
              const _bind$10 = _M0MP312moonbitstack7moonrpc6client8H2Client4feed(client, f);
              let _bind$11;
              if (_bind$10.$tag === 1) {
                const _ok = _bind$10;
                _bind$11 = _ok._0;
              } else {
                const _err = _bind$10;
                _try_err = _err._0;
                break _L$2;
              }
              const _bind$12 = _bind$11.length;
              let _tmp$6 = 0;
              while (true) {
                const _ = _tmp$6;
                if (_ < _bind$12) {
                  const r = _bind$11[_];
                  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(to_server, r);
                  _M0MPC15array5Array4pushGRP312moonbitstack8moonhttp5http25FrameE(fj, _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo11frame__json(r, "C"));
                  _tmp$6 = _ + 1 | 0;
                  continue;
                } else {
                  break;
                }
              }
              break _L;
            }
          }
        } else {
          break;
        }
      }
      continue;
    } else {
      break;
    }
  }
  const reply = _M0MP312moonbitstack7moonrpc6client8H2Client5reply(client, id.val);
  const rb = _M0MPB13StringBuilder21StringBuilder_2einner(0);
  _M0IPB13StringBuilderPB6Logger13write__string(rb, "[");
  let _tmp$6 = 0;
  while (true) {
    const i = _tmp$6;
    if (i < reply.messages.length) {
      if (i > 0) {
        _M0IPB13StringBuilderPB6Logger13write__string(rb, ",");
      }
      _M0IPB13StringBuilderPB6Logger13write__string(rb, `\"${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12json__escape(_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo5ascii(_M0MPC15array5Array2atGsE(reply.messages, i)))}\"`);
      _tmp$6 = i + 1 | 0;
      continue;
    } else {
      break;
    }
  }
  _M0IPB13StringBuilderPB6Logger13write__string(rb, "]");
  return `{\"kind\":\"${kind}\",\"frames\":[${_M0MPC15array5Array4joinGsE(fj, new _M0TPC16string10StringView(",", 0, 1))}],\"grpc_status\":${_M0MPC13int3Int18to__string_2einner(reply.grpc_status, 10)},\"grpc_message\":\"${_M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo12json__escape(reply.grpc_message)}\",\"replies\":${_M0MPB13StringBuilder10to__string(rb)}}`;
}
(() => {
  _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo15js__set__global("moonrpcEncodeMessage", _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo21demo__encode__message);
  _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo15js__set__global("moonrpcRun", _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo9demo__run);
  _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo21demo__encode__message("alice|3|deadbeef|");
  _M0FP512moonbitstack7moonrpc8examples7browser14moonrpc_2ddemo9demo__run("unary");
})();
//# sourceMappingURL=moonrpc-demo.js.map
