{
Fisher-Yates shuffling of consecutive lines in text file.
CRLF format assumed.
}

{$APPTYPE CONSOLE}

uses Classes,TRNG;

Var
C,Count : Integer;
TextList : TStringList;
ser:TRNGinstance;


Function Random64(const range:longword):longword;
begin
Result := TRNG_Random64(ser,range);
end;

Procedure Help;
begin
Writeln;
Writeln('Textfile shuffling using Fisher-Yates and true hardware randomness');
Writeln;
Writeln('Syntax:');
Writeln;
Writeln('fullshuffletrng.exe COMx inputfile.txt outputfile.txt');
Writeln;
Writeln('COMx must be a valid COM port where TRNG is connected (COM1, COM2, COM3...)');
Writeln;
halt;
End;


Begin

If ParamCount<>3 then Help;

trngpro_init(ser,Normal,ParamStr(1));

TextList := TStringList.Create;
TextList.Sorted := False;
TextList.Duplicates := DupAccept;

TextList.LoadFromFile(ParamStr(2));
Count := TextList.Count;

Write(Count);

for C := Count-1 downto 1 do begin
TextList.Exchange(C,Random64(C+1));
write(C,'          ',#13);
end;

Writeln;

TextList.SaveToFile(ParamStr(3));
TextList.Free;

TRNG_Close(ser);

End.

