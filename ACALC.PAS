{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/pcdos-0)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program ACALC;

Uses Crt, Dos;

Type
 TokenType=(Number, _Operator, _Function, OpenParen, CloseParen, Separator);
 TokenRec=Record
  Case Kind: TokenType of
   Number: (Value: Real);
   _Operator,
   _Function: (Symbol: string);
 End;

Const
  MaxStack = 100;

Var
 Expression:String;
 Position:Integer;
 OutputFormat:Char;
 I:Integer;
 R:Real;
 ErrorCode:Integer;

Function CalcFunction(FuncName:String;x,y:Real):Real;Forward;
Function ParseToken:TokenRec;Forward;

Function IsDigit(c:Char):Boolean;Begin
 IsDigit := c in ['0'..'9'];
End;

Function IsLetter(c:Char):Boolean;Begin
 IsLetter := c in ['A'..'Z', 'a'..'z'];
End;

Function IsSpace(c:Char):Boolean;Begin
 IsSpace := c in [' ', #9];
End;

Function GetNumber:Real;
Var
 Base:Integer;
 Value:Real;
 IsHex:Boolean;
Begin
 Value:=0;
 Base:=10;
 IsHex:=False;
 If Position<=Length(Expression)Then Begin
  Case LowerCase(Expression[Position]) of
   'b': begin Base := 2; Inc(Position) end;
   'o': begin Base := 8; Inc(Position) end;
   'x': begin Base := 16; IsHex := True; Inc(Position) end;
  End;
 End;
 While (Position <= Length(Expression)) do Begin
  Case LowerCase(Expression[Position]) of
   '0'..'9': Value:=Value*Base+(Ord(Expression[Position])-Ord('0'));
   'a'..'f': If(IsHex)Then
              Value:=Value*Base+(Ord(LowerCase(Expression[Position]))-Ord('a')+10)
             Else
              Break;
   Else Break;
  End;
  Inc(Position);
 End;
 GetNumber:=Value;
End;

Function GetPriority(Op:String):Integer;Begin
 Case Op[1] of
  '(': GetPriority:=0;
  '+', '-': GetPriority:=1;
  '*', '/', '%': GetPriority:=2;
  '&', ':', '^': GetPriority:=3;
  '{', '}': GetPriority:=4;
  Else GetPriority:=0;
 End;
End;

Function ParseToken:TokenRec;
Var
 s:String;
Begin
 While(Position<=Length(Expression))and IsSpace(Expression[Position]) do Inc(Position);
 If Position>Length(Expression)Then Begin
  ParseToken.Kind:=_Operator;
  ParseToken.Symbol:='';
  Exit;
 End;
 Case Expression[Position] of
  '0'..'9':Begin
   ParseToken.Kind:=Number;
   ParseToken.Value:=GetNumber;
  End;
  '+','-','*','/','%','&',':','^','{','}':Begin
   ParseToken.Kind:=_Operator;
   ParseToken.Symbol:=Expression[Position];
   Inc(Position);
  End;
  '(':Begin
   ParseToken.Kind:=OpenParen;
   ParseToken.Symbol:='(';
   Inc(Position);
  End;
  ')':Begin
   ParseToken.Kind:=CloseParen;
   ParseToken.Symbol:=')';
   Inc(Position);
  End;
  ';':Begin
   ParseToken.Kind:=Separator;
   ParseToken.Symbol:=';';
   Inc(Position);
  End;
  'A'..'Z', 'a'..'z':Begin
   s:='';
   While (Position <= Length(Expression)) and IsLetter(Expression[Position]) do Begin
    s:=s+UpCase(Expression[Position]);
    Inc(Position);
   End;
   ParseToken.Kind:=_Function;
   ParseToken.Symbol:=s;
  End;
   Else
  Begin
   ErrorCode:=1; { Expression invalide }
   ParseToken.Kind:=_Operator;
   ParseToken.Symbol:='';
  End;
 End;
End;

Function CalcFunction(FuncName:String;x,y:Real):Real;Begin
 Case FuncName of
  'ABS': CalcFunction := Abs(x);
  'SQRT': if x >= 0 then CalcFunction := Sqrt(x) else ErrorCode := 2;
  'SIN': CalcFunction:=Sin(x);
  'COS': CalcFunction:=Cos(x);
  'TAN': CalcFunction:=Sin(x)/Cos(x);
  'MAX': CalcFunction:=x;
  'MIN': CalcFunction:=x;
  'PI': CalcFunction:=3.14159265359;
  Else Begin
   ErrorCode:=3; { Fonction inconnu }
   CalcFunction:=0;
  End;
 End;
End;

Function Evaluate:Real;
Var
 ValueStack:Array[1..MaxStack] of Real;
 OperStack:Array[1..MaxStack] of TokenRec;
 ValTop,OpTop:Integer;
 Token:TokenRec;
Begin
 ValTop:=0;
 OpTop:=0;
 ErrorCode:=0;
 Position:=1;  { R‚initialise la position de d‚part de l'expression }
 While ErrorCode = 0 do Begin
  Token:=ParseToken;
  Case Token.Kind of
   Number:Begin
    Inc(ValTop);
    ValueStack[ValTop]:=Token.Value;
   End;
   _Operator:Begin
    If Token.Symbol=''Then Break;  { Fin de l'expression }
     { Traitement des op‚rateurs avec le pr‚c‚dent haut ou ‚gale }
    While(OpTop>0)and(GetPriority(OperStack[OpTop].Symbol) >= GetPriority(Token.Symbol)) do Begin
     If ValTop<2 Then Begin
      ErrorCode := 1;  { Plus d'espace pour les op‚randes }
      Break;
     End;
     Case OperStack[OpTop].Symbol[1] of
      '+':ValueStack[ValTop-1]:=ValueStack[ValTop-1]+ValueStack[ValTop];
      '-':ValueStack[ValTop-1]:=ValueStack[ValTop-1]-ValueStack[ValTop];
      '*':ValueStack[ValTop-1]:=ValueStack[ValTop-1]*ValueStack[ValTop];
      '/':If ValueStack[ValTop]<>0 Then
           ValueStack[ValTop-1] := ValueStack[ValTop-1] / ValueStack[ValTop]
          Else
           ErrorCode:=2;  { Division par z‚ro }
      '%':If ValueStack[ValTop]<>0 Then
           ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) mod Trunc(ValueStack[ValTop])
          Else
           ErrorCode := 2;
      '&': ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) and Trunc(ValueStack[ValTop]);
      ':': ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) or Trunc(ValueStack[ValTop]);
      '^': ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) xor Trunc(ValueStack[ValTop]);
      '{': ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) shl Trunc(ValueStack[ValTop]);
      '}': ValueStack[ValTop-1] := Trunc(ValueStack[ValTop-1]) shr Trunc(ValueStack[ValTop]);
     End;
     Dec(ValTop);
     Dec(OpTop);
    End;
    Inc(OpTop);
    OperStack[OpTop]:=Token;
   End;
   _Function:Begin
    Inc(OpTop);
    OperStack[OpTop]:=Token;
    Token:=ParseToken;  { Demande le paramŠtre de la fonction }
    If Token.Kind<>Number Then Begin
     ErrorCode:=1;
     Break;
    End;
    Inc(ValTop);
    ValueStack[ValTop]:=CalcFunction(OperStack[OpTop].Symbol,Token.Value,0);
    Dec(OpTop);
   End;
   OpenParen:Begin
    Inc(OpTop);
    OperStack[OpTop] := Token;
   End;
   CloseParen:Begin
    While (OpTop>0)and(OperStack[OpTop].Kind <> OpenParen) do Begin
     If ValTop<2 Then Begin
      ErrorCode:=1;
      Break;
     End;
     Case OperStack[OpTop].Symbol[1] of
      '+': ValueStack[ValTop-1]:=ValueStack[ValTop-1] + ValueStack[ValTop];
      '-': ValueStack[ValTop-1]:=ValueStack[ValTop-1] - ValueStack[ValTop];
      '*': ValueStack[ValTop-1]:=ValueStack[ValTop-1] * ValueStack[ValTop];
      '/': If ValueStack[ValTop] <> 0 then
            ValueStack[ValTop-1]:=ValueStack[ValTop-1] / ValueStack[ValTop]
           Else
            ErrorCode:=2;
     End;
     Dec(ValTop);
     Dec(OpTop);
    End;
    If OpTop > 0 Then
     Dec(OpTop)  { EnlŠve les parenthRemove opening parenthesis }
    Else
     ErrorCode := 6;  { Non correspondance des parenthŠses }
   End;
  End;
 End;
  { Traitement des op‚rateurs }
 While (OpTop > 0) and (ErrorCode = 0) do Begin
  If ValTop<2 Then Begin
   ErrorCode := 1;
   Break;
  End;
  Case OperStack[OpTop].Symbol[1] of
   '+': ValueStack[ValTop-1] := ValueStack[ValTop-1] + ValueStack[ValTop];
   '-': ValueStack[ValTop-1] := ValueStack[ValTop-1] - ValueStack[ValTop];
   '*': ValueStack[ValTop-1] := ValueStack[ValTop-1] * ValueStack[ValTop];
   '/': If ValueStack[ValTop] <> 0 Then
         ValueStack[ValTop-1] := ValueStack[ValTop-1] / ValueStack[ValTop]
        Else
         ErrorCode:=2;
  End;
  Dec(ValTop);
  Dec(OpTop);
 End;
 If(ErrorCode=0)and(ValTop=1)Then Evaluate:=ValueStack[1]
  Else
 Begin
  ErrorCode := 1;
   Evaluate := 0;
 End;
End;

Procedure DisplayResult(Value:Real);Begin
 Case UpCase(OutputFormat) of
  'B':WriteLn(Value:0:0, 'B');
  'O':WriteLn(Value:0:0, 'O');
  'X':WriteLn(Value:0:0, 'H');
  'A':Begin
   WriteLn(Value:0:0, 'D');
   WriteLn(Value:0:0, 'B');
   WriteLn(Value:0:0, 'O');
   WriteLn(Value:0:0, 'H');
  End;
  Else WriteLn(Value:0:0);
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('ACALC - Cette commande permet de lancer la calculatrice arithmetique');
  WriteLn;
  WriteLn('Syntaxe: ACALC [/t[:format]]expression [/?]');
  WriteLn;
  WriteLn('  /t[:format]  Format de sortie (D,B,O,X,A)');
  WriteLn('  expression   Expression mathematique');
  WriteLn('  /?           Affiche cette aide');
  Halt;
 End;
 OutputFormat := 'D';
 Expression := '';
 Position := 1;
 ErrorCode := 0;
  { Analyse la ligne de commande }
 For i:=1 to ParamCount do Begin
  If(ParamStr(i)[1]='/')and(UpCase(ParamStr(i)[2])='T')Then Begin
   If Length(ParamStr(i)) >= 4 Then OutputFormat:=UpCase(ParamStr(i)[4]);
  End
   Else
  Expression:=Expression+ParamStr(i);
 End;
 R:=Evaluate;
 If ErrorCode <> 0 Then Begin
  Case ErrorCode of
   1: WriteLn('Erreur: Expression invalide');
   2: WriteLn('Erreur: Division par zero');
   3: WriteLn('Erreur: Fonction non reconnue');
   4: WriteLn('Erreur: Parentheses non equilibrees');
   Else WriteLn('Erreur inconnue');
  End;
  Halt(1);
 End
  Else
 DisplayResult(R);
END.
