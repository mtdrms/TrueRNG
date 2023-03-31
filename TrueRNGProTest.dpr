{$APPTYPE CONSOLE}

Uses
SysUtils,
trng;

Const Size = 1024*4; // change as needed

var
  F:File;
  N:string;
  S:string;
  ser:TRNGinstance;
 
  
Procedure AnyToFile(Const D; Const Size:LongWord; Const FileName:String);
Var 
a:array[1..1] of byte absolute D;
f:file;
begin
AssignFile(F,FileName); Rewrite(F,1); BlockWrite(F,A[1],Size); Close(f);
end;

begin
N := FormatDateTime('yyyymmddhhnnsszzz',Now)+'.bin';

SetLength(S,Size);
trngpro_init(ser,Normal,ParamStr(1));

FillChar(S[1],Length(S),0); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'Normal_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,RNG1normal); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'RNG1normal_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,RNG2normal); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'RNG2normal_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,RawBinary); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'RawBinary_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,PowerSupplyDebug); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'PowerDebug_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,RNGdebug); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'RNGdebug_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,RawAscii); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'RawAscii_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,Unwhitened); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'Unwhitened_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,NormalAscii); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'NormalAscii_'+N);
Writeln(IsModeWhitened(ser));

FillChar(S[1],Length(S),0); TRNGPro_SetMode(ser,NormalAsciiSlow); TRNG_FillRandom(ser,@S[1],Length(S)); AnyToFile(S[1],Length(S),'NormalAsciiSlow_'+N);
Writeln(IsModeWhitened(ser));

TRNG_Close(ser);

end.
