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

{Returns random extended float number with 64-bit precision}
function TRNG_extended(var ser: TRNGinstance):extended;

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
ZLib,
Windows;

Var
NormalMode : Boolean;
FormatSettings:TFormatSettings;
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
NormalMode := True;
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
ser.Purge; // "Official" method to purge serial interface buffers
SetLength(S,128);
ser.RecvBuffer(@S[1],Length(S)); // Required to empty USB buffer. Experiments shown that even 128 bytes are retained in driver memory.
FillChar(S[1],Length(S),0);
SetLength(S,0);
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
NormalMode := (Mode in [Normal,RNG1normal,RNG2normal]);
End;
{---------------------------------------------------------------------------}
function TRNG_long(var ser: TRNGinstance): Integer;
Var R:LongWord;
begin
  TRNG_long := 0;
  If NormalMode Then begin
  ser.RecvBuffer(@R,4);
  TRNG_long := R shr 1;
  end;
end;
{---------------------------------------------------------------------------}
function TRNG_dword(var ser: TRNGinstance):LongWord;
Var R:LongWord;  
begin
  TRNG_dword := 0;
  If NormalMode Then begin
  ser.RecvBuffer(@R,4);
  TRNG_dword := R;
  end;
end;
{---------------------------------------------------------------------------}
function TRNG_word(var ser: TRNGinstance): word;
type
  TwoWords = packed record
               L,H: word
             end;
begin
  TRNG_word := 0;
  If NormalMode Then TRNG_word := TwoWords(TRNG_dword(ser)).H;
end;
{---------------------------------------------------------------------------}
function TRNG_double(var ser: TRNGinstance): double;
  {random double [0..1) with 32 bit precision}
begin
   TRNG_Double := 0.0;
   If NormalMode Then TRNG_double := (TRNG_dword(ser) + 2147483648.0) / 4294967296.0;
end;
{---------------------------------------------------------------------------}
function TRNG_double53(var ser: TRNGinstance): double;
  {random double in [0..1) with full double 53 bit precision}
var
  hb,lb: LongWord;
begin
  TRNG_Double53 := 0.0;
  If NormalMode Then begin
  hb := TRNG_dword(ser) shr 5;
  lb := TRNG_dword(ser) shr 6;
  TRNG_double53 := (hb*67108864.0+lb)/9007199254740992.0;
  end;
end;
{---------------------------------------------------------------------------}
function TRNG_extended(var ser: TRNGinstance):extended;
var s:string;
i:integer;
Begin
TRNG_extended := 0.0;
If NormalMode Then begin
s := '0'+FormatSettings.DecimalSeparator;
for i := 1 to 6 do s := s+LZ(TRNG_Random(ser,1000),3);
TRNG_extended := StrToFloat(S);
end;
End;
{---------------------------------------------------------------------------}
Function TRNG_Random(var ser: TRNGinstance; const range:word):word;
var seed:longword;
begin
seed:=TRNG_dword(ser);
TRNG_Random := 0;
If NormalMode Then begin
TRNG_Random:=((seed shr 16)*Range+((seed and $ffff)*Range shr 16)) shr 16;
end;
end;
{---------------------------------------------------------------------------}
Function TRNG_Random64(var ser: TRNGinstance; const range:longword):longword;
var seed:int64;
begin
TRNG_Random64:= 0;
seed := TRNG_Int64(ser);
If NormalMode Then begin
TRNG_Random64:=((seed shr 32)*Range+((seed and $ffffffff)*Range shr 32)) shr 32;
end;
end;
{---------------------------------------------------------------------------}
Function TRNG_Int64(var ser: TRNGinstance):Int64;
var seed:int64;
begin
TRNG_Int64 := 0;
If NormalMode Then begin
ser.RecvBuffer(@seed,8);
TRNG_Int64:=seed;
end;
end;
{---------------------------------------------------------------------------}
Function TRNG_Random64range(var ser: TRNGinstance; const amin,amax:int64):int64;
Begin
TRNG_Random64range  := 0;
If NormalMode Then begin
TRNG_Random64range:=TRNG_ValRangeNoMod64(ser,Abs(amin-amax)+1)+Min(amax,amin);
end;
end;
{---------------------------------------------------------------------------}
Function Seed_Random64(const seed:int64; const range:longword):longword;
begin
Seed_Random64:=((seed shr 32)*Range+((seed and $ffffffff)*Range shr 32)) shr 32;
end;
{---------------------------------------------------------------------------}
Function Seed_Random(const seed:LongWord; const range:word):word;
begin
Seed_Random:=((seed shr 16)*Range+((seed and $ffff)*Range shr 16)) shr 16;
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
  TRNG_ValRangeNoMod := 0;
  If NormalMode Then begin
  i:=0;
  Range := inRange;
  if range<1 then range:=1;
  while range > (p[i]) do i:=i+1;
  if i>psize then i:=psize;
  filter:=p[i];
  repeat
    n:=TRNG_dword(ser) and filter;
  until n<range;
  TRNG_ValRangeNoMod:=n;
  end;
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
  TRNG_ValRangeNoMod64 := 0;
  If NormalMode Then begin
  i:=0;
  Range := Abs(inRange);
  while range > (p[i]) do i:=i+1;
  if i>psize then i:=psize;
  filter:=p[i];
  repeat
    n:=Abs(TRNG_Int64(ser)) and filter;
  until n<range;
  TRNG_ValRangeNoMod64:=n;
  end;
end;
{---------------------------------------------------------------------------}
Procedure TRNG_FillRandom(var ser: TRNGinstance; Something:Pointer; Const Size:Integer);
Begin
ser.RecvBuffer(something,size);
End;
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
NormalMode := False;
GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT,FormatSettings);
end.
