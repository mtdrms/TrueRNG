unit TRNG;

interface

uses SynaSer; {Ararat Synapse SynaSer library: http://www.ararat.cz/synapse/doku.php/download}

Type
TRNGinstance = tBlockSerial; // TRNG "instance" is just a serial port.
StrArray = Array Of String;

OutputMode = (Normal, {Supported by TrueRNGProv1/TrueRNGprov2/TrueRNGv3}
{TrueRNGProV1/V2 ONLY -->} PowerSupplyDebug, RNGdebug, RNG1normal, RNG2normal, RawBinary, RawAscii, 
{TrueRNGProV2 ONLY -->} Unwhitened, NormalAscii, NormalAsciiSlow);

{Initializes TRNGv3 instance. Only single instance per device allowed.}  
procedure TRNGv3_Init(var ser: TRNGinstance; Const Portname:String);

{Initializes and sets mode of TRNGPro instance. Only single instance per device allowed.}  
procedure TRNGPro_Init(var ser: TRNGinstance; Const Mode:OutputMode; Const Portname:String);

{Sets mode of TRNGPro}
procedure TRNGPro_SetMode(Var ser:TRNGinstance; Const Mode:OutputMode);

{Closes TRNG instance}
procedure TRNG_Close(Var ser:TRNGinstance);

function TRNGports(Const minport,maxport:Integer):StrArray;

function IsModeWhitened(var ser: TRNGinstance):Boolean;

{Returns random signed 32-bit integer}
function TRNG_long(var ser: TRNGinstance): Integer;

{Returns random unsigned 32-bit integer}
function TRNG_dword(var ser: TRNGinstance):LongWord;

{Returns random unsigned 32-bit integer}
Function TRNG_FDR(Var ser: TRNGinstance; const n:longword):longword; //FastDiceRoller

{Returns random unsigned 32-bit integer}
Function TRNG_KY(Var ser: TRNGinstance; const n:longword):Longword; // Knuth-Yao

{Returns random signed 64-bit integer}  
function TRNG_Int64(var ser: TRNGinstance):Int64;

{Returns random unsigned 32-bit integer in given range}    
Function TRNG_ValRangeNoMod(Var ser: TRNGinstance; Const InRange: Cardinal):Cardinal;

{Returns random signed 64-bit integer in given range}    
Function TRNG_ValRangeNoMod64(Var ser: TRNGinstance; Const InRange: Int64):Int64;

{Returns random unsigned 16-bit integer}
function TRNG_word(var ser: TRNGinstance): word;

{Returns random double float number}
function TRNG_double(var ser: TRNGinstance): double;

{Returns random double float number with 53-bit precision}
function TRNG_double53(var ser: TRNGinstance): double;

{Returns random extended float number in range [-1,1] with 64-bit precision}
function TRNG_extended(var ser: TRNGinstance):extended;

{Returns random extended float number in range [0,1] with 64-bit precision}
function TRNG_extended_positive(var ser: TRNGinstance):extended;

{Returns random unsigned 16-bit integer in given range}      
Function TRNG_Random(var ser: TRNGinstance; const range:word):word;

{Returns random unsigned 32-bit integer in given range}      
Function TRNG_Random64(var ser: TRNGinstance; const range:longword):longword;

{Returns random signed 64-bit integer in given range}
Function TRNG_Random64range(var ser: TRNGinstance; const amin,amax:int64):int64;

{Fills memory at pointer with random data from TRNG}
Procedure TRNG_FillRandom(var ser: TRNGinstance; Something:Pointer; Const Size:Integer);

{---------------------------------------------------------------------------}

implementation

uses
SysUtils,
Math,
ZLib;

Var
MaxInt64 : Extended;
FlipWord:int64 = 0;
FlipPos:Integer = 0;

{---------------------------------------------------------------------------}
function Min(a, b: Int64): Int64;
begin
  if a < b then
    Result := a
  else
    Result := b;
end;
{---------------------------------------------------------------------------}
function Max(a, b: Int64): Int64;
begin
  if a > b then
    Result := a
  else
    Result := b;
end;
{---------------------------------------------------------------------------}
Function LZ(const aNumber:Int64; Const Length : integer):string;
begin
   result := SysUtils.Format('%.*d', [Length, aNumber]) ;
end;
{---------------------------------------------------------------------------}
procedure TRNGv3_Init(var ser: TRNGinstance; Const Portname:String);
Var S:String;
Begin
ser := TRNGinstance.Create;
FillChar(Ser.DCB,SizeOf(ser.DCB),0); // Set all to 0/False
Ser.DCB.BaudRate := 115200; // Any legal value will do; it's not used.
ser.DCB.Flags := dcb_Binary // Binary mode; no EOF check
or dcb_DtrControlEnable // DTR flow control type, must be on
or dcb_TXContinueOnXoff // XOFF continues Tx
or dcb_RtsControlEnable; // RTS flow control
//these should have no effect, so we use typical values
ser.DCB.ByteSize := 8; // 8
ser.DCB.Parity := 0;  // N
ser.DCB.StopBits := 1; // 1
ser.Connect(Trim(Portname));
ser.Purge; // "Official" method to purge serial interface buffers
SetLength(S,128);
ser.RecvBuffer(@S[1],Length(S)); // Required to empty USB buffer. Experiments shown that some output bytes are retained in driver memory.
FillChar(S[1],Length(S),0);
SetLength(S,0);
End;
{---------------------------------------------------------------------------}
procedure TRNGPro_Init(var ser: TRNGinstance; Const Mode:OutputMode; Const Portname:String);
Begin
ser := TRNGinstance.Create;
FillChar(Ser.DCB,SizeOf(ser.DCB),0); // Set all to 0/False
Ser.DCB.BaudRate := 115200; // Any legal value will do; it's not used.
ser.DCB.Flags := dcb_Binary // Binary mode; no EOF check
or dcb_DtrControlEnable // DTR flow control type, must be on
or dcb_TXContinueOnXoff // XOFF continues Tx
or dcb_RtsControlEnable; // RTS flow control
//these should have no effect, so we use typical values
ser.DCB.ByteSize := 8; // 8
ser.DCB.Parity := 0;  // N
ser.DCB.StopBits := 1; // 1
ser.Connect(Portname);
TRNGPro_SetMode(ser,Mode);
End;
{---------------------------------------------------------------------------}
Procedure TRNG_Close(var ser:TRNGinstance);
Var S:String;
begin
SetLength(S,128);
ser.RecvBuffer(@S[1],Length(S)); // Required to empty USB buffer. Experiments shown that even 128 bytes are retained in driver memory.
FillChar(S[1],Length(S),0);
SetLength(S,0);
ser.Purge; // "Official" method to purge serial interface buffers
ser.Destroy;
end;
{---------------------------------------------------------------------------}
procedure TRNGPro_SetMode(Var ser:TRNGinstance; Const Mode:OutputMode);
const Modes : Array[OutPutMode] of Integer = (
300,    {Normal Mode - Streams combined + Mersenne Twister}
1200,   {Power Supply Debug - PS Voltage in mV in ASCII}
2400,   {RNG Debug - RNG Debug 0x0RRR 0x0RRR in ASCII}
4800,   {Normal - RNG1 + Mersenne Twister}
9600,   {Normal - RNG2 + Mersenne Twister}
19200,  {RAW Binary - Raw ADC Samples in Binary Mode}
38400,  {RAW ASCII - Raw ADC Samples in Ascii Mode}
57600,  {Unwhitened RNG1-RNG2 (TrueRNGproV2 Only)}
115200, {Normal in Ascii Mode (TrueRNGproV2 Only)}
230400  {Normal in Ascii Mode - Slow for small devices (TrueRNGproV2 Only)}
);
Var S:String;
Begin
// "Knock" Sequence to activate mode change START
Ser.DCB.BaudRate := 110; ser.SetCommState;
Ser.DCB.BaudRate := 300; ser.SetCommState;
Ser.DCB.BaudRate := 110; ser.SetCommState;
// "Knock" Sequence to activate mode change END
Ser.DCB.BaudRate := Modes[Mode]; ser.SetCommState;
ser.Purge; // "Official" method to purge serial interface buffers
SetLength(S,128);
ser.RecvBuffer(@S[1],Length(S)); // Required to empty USB buffer. Experiments shown that some output bytes are retained in driver memory.
FillChar(S[1],Length(S),0);
SetLength(S,0);
End;
{---------------------------------------------------------------------------}
function TRNG_long(var ser: TRNGinstance): Integer;
begin
  ser.RecvBuffer(@Result,4);
end;
{---------------------------------------------------------------------------}
function TRNG_dword(var ser: TRNGinstance):LongWord;
begin
  ser.RecvBuffer(@Result,4);
end;
{---------------------------------------------------------------------------}
function TRNG_word(var ser: TRNGinstance): word;
begin
   ser.RecvBuffer(@Result,2);
end;
{---------------------------------------------------------------------------}
function TRNG_double(var ser: TRNGinstance): double;
  {random double [0..1) with 32 bit precision}
begin
   Result := (TRNG_dword(ser) + 2147483648.0) / 4294967296.0;
end;
{---------------------------------------------------------------------------}
function TRNG_double53(var ser: TRNGinstance): double;
  {random double in [0..1) with full double 53 bit precision}
var hb,lb: LongWord;
begin
  hb := TRNG_dword(ser) shr 5;
  lb := TRNG_dword(ser) shr 6;
  Result := (hb*67108864.0+lb)/9007199254740992.0;
end;
{---------------------------------------------------------------------------}
function TRNG_extended(var ser: TRNGinstance):extended;
Begin
// Divide the random numerator by MaxInt64 to get a random Extended number in [-1, 1)
Result := TRNG_Int64(ser) / MaxInt64;
End;
{---------------------------------------------------------------------------}
function TRNG_extended_positive(var ser: TRNGinstance):extended;
Begin
// Divide the random numerator by MaxInt64 to get a random Extended number in [0, 1)
Result := (TRNG_Int64(ser) / MaxInt64 + 1) * 0.5;
End;
{---------------------------------------------------------------------------}
Function TRNG_Random(var ser: TRNGinstance; const range:word):word;
var seed:longword;
begin
seed:=TRNG_dword(ser);
Result:=((seed shr 16)*Range+((seed and $ffff)*Range shr 16)) shr 16;
end;
{---------------------------------------------------------------------------}
Function TRNG_Random64(var ser: TRNGinstance; const range:longword):longword;
var seed:int64;
begin
seed := TRNG_Int64(ser);
Result:=((seed shr 32)*Range+((seed and $ffffffff)*Range shr 32)) shr 32;
end;
{---------------------------------------------------------------------------}
Function TRNG_Int64(var ser: TRNGinstance):Int64;
begin
ser.RecvBuffer(@Result,8);
end;
{---------------------------------------------------------------------------}
Function TRNG_Random64range(var ser: TRNGinstance; const amin,amax:int64):int64;
Begin
Result:=TRNG_ValRangeNoMod64(ser,Abs(amin-amax)+1)+Min(amax,amin);
end;
{---------------------------------------------------------------------------}
Function Seed_Random64(const seed:int64; const range:longword):longword;
begin
Result:=((seed shr 32)*Range+((seed and $ffffffff)*Range shr 32)) shr 32;
end;
{---------------------------------------------------------------------------}
Function Seed_Random(const seed:LongWord; const range:word):word;
begin
Result:=((seed shr 16)*Range+((seed and $ffff)*Range shr 16)) shr 16;
end;
{---------------------------------------------------------------------------}
Function TRNG_ValRangeNoMod(Var ser: TRNGinstance; Const InRange: Cardinal):Cardinal;
const
  psize=30;
  p : array[0..psize] of Cardinal=(
    3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535,131071,262143,
    524287,1048575,2097151,4194303,8388607,16777215,33554431,67108863,134217727,
    268435455,536870911,1073741823,2147483647,4294967295);
var
  i : Integer;
  Range,filter, n : Cardinal;

begin
  i:=0;
  Range := inRange;
  if range<1 then range:=1;
  while range > (p[i]) do i:=i+1;
  if i>psize then i:=psize;
  filter:=p[i];
  repeat
    n:=TRNG_dword(ser) and filter;
  until n<range;
  Result:=n;
end;
{---------------------------------------------------------------------------}
Function TRNG_ValRangeNoMod64(Var ser: TRNGinstance; Const InRange: Int64):Int64;
const
  psize=61;
  p : array[0..psize] of Int64=(
3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535,131071,262143,524287,1048575,2097151,4194303,8388607,16777215,33554431,67108863,
134217727,268435455,536870911,1073741823,2147483647,4294967295,8589934591,17179869183,34359738367,68719476735,137438953471,274877906943,549755813887,
1099511627775,2199023255551,4398046511103,8796093022207,17592186044415,35184372088831,70368744177663,140737488355327,281474976710655,562949953421311,
1125899906842623,2251799813685247,4503599627370495,9007199254740991,18014398509481983,36028797018963967,72057594037927935,144115188075855871,
288230376151711743,576460752303423487,1152921504606846975,2305843009213693951,4611686018427387903,9223372036854775806);
var
  i : Integer;
  Range,filter, n : Int64;

begin
  i:=0;
  Range := Abs(inRange);
  while range > (p[i]) do i:=i+1;
  if i>psize then i:=psize;
  filter:=p[i];
  repeat
    n:=Abs(TRNG_Int64(ser)) and filter;
  until n<range;
  Result:=n;
end;
{---------------------------------------------------------------------------}
Procedure TRNG_FillRandom(var ser: TRNGinstance; Something:Pointer; Const Size:Integer);
Begin
ser.RecvBuffer(something,size);
End;
{---------------------------------------------------------------------------}
function NextBit(Var ser: TRNGinstance; Var flip_word:Int64; Var flip_pos:Integer):Integer;
begin
if(flip_pos=0) then begin
flip_word := TRNG_Int64(ser);
flip_pos := 64;
end;
Dec(flip_pos);
Result := (flip_word and (Int64(1) shl flip_pos)) shr flip_pos;
end;
{---------------------------------------------------------------------------}
{ Lumbroso J. (2013)
Optimal discrete uniform generation from coin flips, and applications.
arXiv:1304.1916 }
Function TRNG_FDR(Var ser: TRNGinstance; const n:longword):longword; //FastDiceRoller
var
v : longword;
c : longword;
begin
v := 1;
c := 0;
while(true) do begin
v := (v shl 1);
c := (c shl 1) + NextBit(ser,flipword,flippos);
if (v >= n) then begin
if(c < n) then begin result := c; Exit; end
else
begin
v := v - n;
c := c - n;
end;
end;
end;
end;
{---------------------------------------------------------------------------}
Function TRNG_KY(Var ser: TRNGinstance; const n:longword):Longword; // Knuth-Yao
Var v,c,d:longword;
begin
v := 1; c := 0;
while(true) do begin
while (v<n) do begin
v := (v shl 1);
c := (c shl 1)+NextBit(ser,flipword,flippos);
end;
d := v-n;
if (c >= d) then begin
Result := c - d; Exit;
end
else v := d;
end;
end;
{---------------------------------------------------------------------------}
function CompressStr(const S : String) : String;
var
  Buffer : Pointer;
  Size : Integer;
begin
  try
    try
      CompressBuf(PChar(S), Length(S), Buffer, Size);
      SetLength(Result, Size);
      Move(Buffer^, Result[1], Size);
    except
      Buffer := nil;
    end;
  finally
    FreeMem(Buffer);
  end;
end;
{---------------------------------------------------------------------------}
Function TRNGports(Const minport,maxport:Integer):StrArray;
var
S,P:string;
I:Integer;
N:Integer;
R:TRNGinstance;
begin
N := 0;
for i := minport to maxport do begin
SetLength(S,1000);
FillChar(S[1],Length(S),0);
P := 'COM'+IntToStr(i);
TRNGPro_Init(R,Normal,P);
TRNG_FillRandom(R,@S[1],Length(S));
TRNG_Close(R);
S := CompressStr(S);
if Length(S)>1000 then begin
Inc(N);
SetLength(Result,N);
Result[N-1] := P;
end;
end;
FillChar(S[1],Length(S),0);
SetLength(S,0);
end;
{---------------------------------------------------------------------------}
function IsModeWhitened(var ser: TRNGinstance):Boolean;
Var TempStr:String;
Begin
SetLength(TempStr,1000);
ser.RecvBuffer(@TempStr[1],Length(TempStr));
Result := Length(TempStr)<Length(CompressStr(TempStr));
FillChar(TempStr[1],Length(TempStr),#0);
SetLength(TempStr,0);
End;
{---------------------------------------------------------------------------}

begin
MaxInt64 := Power(2, 63);
end.
