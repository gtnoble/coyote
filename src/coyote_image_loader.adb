with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Image_Decoder;
with Coyote_Image_IO;
with Gdk.Pixbuf;
with Interfaces.C;

package body Coyote_Image_Loader is
   use type Coyote_Image_IO.Descriptor;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Interfaces.C.int;

   function Is_Control (Value : String) return Boolean is
   begin
      for Ch of Value loop
         if Character'Pos (Ch) < 16#20# or else Character'Pos (Ch) = 16#7F#
         then
            return True;
         end if;
      end loop;
      return False;
   end Is_Control;

   function Is_Scheme (Value : String) return Boolean is
      Colon : Natural := 0;
   begin
      for I in Value'Range loop
         if Value (I) = ':' then
            Colon := I;
            exit;
         elsif Value (I) = '/' then
            return False;
         end if;
      end loop;
      if Colon = 0 or else Colon = Value'First
        or else not
        (Value (Value'First) in 'A' .. 'Z'
         or else Value (Value'First) in 'a' .. 'z')
      then
         return False;
      end if;
      for I in Value'First + 1 .. Colon - 1 loop
         if not
           (Ada.Characters.Handling.Is_Alphanumeric (Value (I))
            or else Value (I) = '+' or else Value (I) = '.'
            or else Value (I) = '-')
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Scheme;

   function Hex_Value (Ch : Character) return Integer is
   begin
      if Ch in '0' .. '9' then
         return Character'Pos (Ch) - Character'Pos ('0');
      elsif Ch in 'a' .. 'f' then
         return Character'Pos (Ch) - Character'Pos ('a') + 10;
      elsif Ch in 'A' .. 'F' then
         return Character'Pos (Ch) - Character'Pos ('A') + 10;
      end if;
      return -1;
   end Hex_Value;

   function Unescape (Value : String) return String is
      Result : Unbounded_String;
      I      : Integer := Value'First;
   begin
      while I <= Value'Last loop
         if Value (I) = '%' then
            if I + 2 > Value'Last then
               return "";
            end if;
            declare
               High : constant Integer := Hex_Value (Value (I + 1));
               Low  : constant Integer := Hex_Value (Value (I + 2));
            begin
               if High < 0 or else Low < 0 or else High * 16 + Low < 16#20#
                 or else High * 16 + Low = 16#7F#
               then
                  return "";
               end if;
               Append (Result, Character'Val (High * 16 + Low));
            end;
            I := I + 3;
         else
            Append (Result, Value (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (Result);
   end Unescape;

   function Local_Path (Root, Destination : String) return String is
      Decoded : Unbounded_String;
   begin
      if Destination'Length = 0 or else Is_Control (Destination) then
         return "";
      elsif Destination'Length >= 5
        and then Destination (Destination'First .. Destination'First + 4)
          = "file:"
      then
         if Destination'Length <= 7
           or else Destination (Destination'First .. Destination'First + 6)
             /= "file://"
         then
            return "";
         end if;
         declare
            Uri_Path : constant String :=
              Destination (Destination'First + 7 .. Destination'Last);
         begin
            if Uri_Path'Length = 0 or else Uri_Path (Uri_Path'First) /= '/'
              or else Ada.Strings.Fixed.Index (Uri_Path, "?") /= 0
              or else Ada.Strings.Fixed.Index (Uri_Path, "#") /= 0
            then
               return "";
            end if;
            Decoded := To_Unbounded_String (Unescape (Uri_Path));
         end;
      elsif Is_Scheme (Destination) then
         return "";
      else
         Decoded := To_Unbounded_String (Unescape (Destination));
      end if;
      if Length (Decoded) = 0 or else Is_Control (To_String (Decoded)) then
         return "";
      elsif Element (Decoded, 1) = '/' then
         return To_String (Decoded);
      end if;
      return Root & "/" & To_String (Decoded);
   end Local_Path;

   function Canonical (Path : String) return String is
      Result : Unbounded_String;
      Parts  : array (1 .. 256)
        of Unbounded_String;
      Count  : Natural := 0;
      Start  : Integer := Path'First;
   begin
      if Path'Length = 0 or else Path (Path'First) /= '/' then
         return "";
      end if;
      while Start <= Path'Last loop
         declare
            Stop : Integer := Start;
         begin
            while Stop <= Path'Last and then Path (Stop) /= '/' loop
               Stop := Stop + 1;
            end loop;
            if Stop > Start then
               declare
                  Part : constant String := Path (Start .. Stop - 1);
               begin
                  if Part = ".." then
                     if Count = 0 then
                        return "";
                     end if;
                     Count := Count - 1;
                  elsif Part /= "." then
                     if Count = Parts'Last then
                        return "";
                     end if;
                     Count         := Count + 1;
                     Parts (Count) := To_Unbounded_String (Part);
                  end if;
               end;
            end if;
            Start := Stop + 1;
         end;
      end loop;
      Append (Result, "/");
      for I in 1 .. Count loop
         if I > 1 then
            Append (Result, "/");
         end if;
         Append (Result, To_String (Parts (I)));
      end loop;
      return To_String (Result);
   end Canonical;

   function Has_Signature (Bytes : String) return Boolean is
   begin
      return
        (Bytes'Length >= 8
         and then Character'Pos (Bytes (Bytes'First)) = 16#89#
         and then Bytes (Bytes'First + 1 .. Bytes'First + 7)
           = "PNG" & ASCII.CR & ASCII.LF & Character'Val (16#1A#) & ASCII.LF)
        or else
        (Bytes'Length >= 3
         and then Character'Pos (Bytes (Bytes'First)) = 16#FF#
         and then Character'Pos (Bytes (Bytes'First + 1)) = 16#D8#
         and then Character'Pos (Bytes (Bytes'First + 2)) = 16#FF#);
   end Has_Signature;

   procedure On_Size_Prepared
     (Loader : Coyote_Image_Decoder.Loader_Handle;
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int;
      State  : Coyote_Image_Decoder.State_Access) with
     Convention => C;

   procedure On_Size_Prepared
     (Loader : Coyote_Image_Decoder.Loader_Handle;
      Width  : Interfaces.C.int;
      Height : Interfaces.C.int;
      State  : Coyote_Image_Decoder.State_Access)
   is
   begin
      if Width <= 0 or else Height <= 0 or else Width > Max_Side
        or else Height > Max_Side
        or else Long_Long_Integer (Width) * Long_Long_Integer (Height)
          > Max_Pixels
      then
         State.Invalid := True;
         Coyote_Image_Decoder.Set_Size (Loader, 1, 1);
      else
         begin
            declare
               Scale         : constant Long_Float :=
                 Long_Float'Min
                   (1.0,
                    Long_Float'Min
                      (Long_Float (State.Max_Width) / Long_Float (Width),
                       Long_Float (Max_Height) / Long_Float (Height)));
               Output_Width  : constant Integer    :=
                 Integer'Max (1, Integer (Long_Float (Width) * Scale));
               Output_Height : constant Integer    :=
                 Integer'Max (1, Integer (Long_Float (Height) * Scale));
            begin
               Coyote_Image_Decoder.Set_Size
                 (Loader,
                  Interfaces.C.int (Output_Width),
                  Interfaces.C.int (Output_Height));
            end;
         exception
            when others =>
               State.Invalid := True;
               Coyote_Image_Decoder.Set_Size (Loader, 1, 1);
         end;
      end if;
   end On_Size_Prepared;

   procedure Load_Raw
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error       : out Unbounded_String)
   is
      Root_FD        : Coyote_Image_IO.Descriptor         :=
        Coyote_Image_IO.Invalid_Descriptor;
      Directory_FD   : Coyote_Image_IO.Descriptor         :=
        Coyote_Image_IO.Invalid_Descriptor;
      File_FD        : Coyote_Image_IO.Descriptor         :=
        Coyote_Image_IO.Invalid_Descriptor;
      Decoder        : Coyote_Image_Decoder.Loader_Handle :=
        Coyote_Image_Decoder.Null_Loader;
      Decoder_Closed : Boolean                            := False;
      Size_State     : aliased Coyote_Image_Decoder.Decode_State;
      Data           : Unbounded_String;
      Buffer         : String (1 .. 16_384);
   begin
      Pixbuf := Coyote_Image_Decoder.Null_Pixbuf;
      Error  := Null_Unbounded_String;
      begin
         if Root'Length = 0 or else Is_Control (Root)
           or else Is_Control (Destination)
         then
            Error := To_Unbounded_String ("Image path is invalid");
         else
            Coyote_Image_IO.Open_Root (Root, Root_FD);
            if Root_FD = Coyote_Image_IO.Invalid_Descriptor then
               Error := To_Unbounded_String ("Image root is not accessible");
            else
               Directory_FD := Coyote_Image_IO.Duplicate (Root_FD);
               if Directory_FD = Coyote_Image_IO.Invalid_Descriptor then
                  Error :=
                    To_Unbounded_String
                      ("Image root descriptor could not be duplicated");
               end if;
               declare
                  Root_Path      : constant String :=
                    Coyote_Image_IO.Readlink_Root (Root_FD);
                  Target         : constant String :=
                    Local_Path (Root_Path, Destination);
                  Canonical_Root : constant String := Canonical (Root_Path);
                  Canonical_File : constant String := Canonical (Target);
                  Relative       : Unbounded_String;
               begin
                  if Root_Path'Length = 0 or else Canonical_Root'Length = 0
                    or else
                    (Root_Path'Length >= 10
                     and then Root_Path (Root_Path'Last - 9 .. Root_Path'Last)
                       = " (deleted)")
                  then
                     Error :=
                       To_Unbounded_String
                         ("Image root path cannot be resolved");
                  elsif Target'Length = 0 then
                     Error :=
                       To_Unbounded_String
                         ("Image path is invalid or non-local");
                  elsif Canonical_File'Length = 0 then
                     Error :=
                       To_Unbounded_String ("Image path escapes its root");
                  else
                     declare
                        R : constant String := Canonical_Root;
                        F : constant String := Canonical_File;
                     begin
                        if R /= "/"
                          and then
                          (F'Length < R'Length
                           or else F (F'First .. F'First + R'Length - 1) /= R
                           or else
                           (F'Length > R'Length
                            and then F (F'First + R'Length) /= '/'))
                        then
                           Error :=
                             To_Unbounded_String
                               ("Image path escapes its root");
                        elsif R = "/" then
                           Relative :=
                             To_Unbounded_String (F (F'First + 1 .. F'Last));
                        elsif F'Length = R'Length then
                           Error :=
                             To_Unbounded_String ("Image path is not a file");
                        else
                           Relative :=
                             To_Unbounded_String
                               (F (F'First + R'Length + 1 .. F'Last));
                        end if;
                     end;
                  end if;
                  if Length (Error) = 0 and then Length (Relative) = 0 then
                     Error := To_Unbounded_String ("Image path is not a file");
                  end if;
                  if Length (Error) = 0 then
                     declare
                        Text  : constant String := To_String (Relative);
                        Start : Positive        := Text'First;
                     begin
                        while Start <= Text'Last loop
                           declare
                              Stop : Natural := Start;
                           begin
                              while Stop <= Text'Last
                                and then Text (Stop) /= '/'
                              loop
                                 Stop := Stop + 1;
                              end loop;
                              declare
                                 Part : constant String            :=
                                   Text (Start .. Stop - 1);
                                 Next : Coyote_Image_IO.Descriptor :=
                                   Coyote_Image_IO.Invalid_Descriptor;
                              begin
                                 if Part = "." or else Part = ".." then
                                    Error :=
                                      To_Unbounded_String
                                        ("Invalid image path component");
                                 elsif Stop <= Text'Last then
                                    Coyote_Image_IO.Open_Directory
                                      (Directory_FD, Part, Next);
                                    if Next
                                      = Coyote_Image_IO.Invalid_Descriptor
                                    then
                                       Error :=
                                         To_Unbounded_String
                                           ("Inaccessible image directory or symlink");
                                    else
                                       Coyote_Image_IO.Close (Directory_FD);
                                       Directory_FD := Next;
                                    end if;
                                 else
                                    Coyote_Image_IO.Open_File
                                      (Directory_FD, Part, File_FD);
                                    if File_FD
                                      = Coyote_Image_IO.Invalid_Descriptor
                                    then
                                       Error :=
                                         To_Unbounded_String
                                           ("Inaccessible image file or symlink");
                                    end if;
                                 end if;
                                 exit when Length (Error) /= 0
                                   or else Stop > Text'Last;
                                 Start := Stop + 1;
                              end;
                           end;
                        end loop;
                     end;
                  end if;
                  if Length (Error) = 0 then
                     declare
                        Attributes : Coyote_Image_IO.File_Attributes;
                     begin
                        Coyote_Image_IO.Attributes (File_FD, Attributes);
                        if not Attributes.Is_Regular then
                           Error :=
                             To_Unbounded_String
                               ("Image path is not a regular file");
                        elsif Attributes.Size < 0
                          or else Attributes.Size > Max_Source_Bytes
                        then
                           Error :=
                             To_Unbounded_String
                               ("Image exceeds the 8 MiB size limit");
                        end if;
                     end;
                  end if;
               end;
            end if;
         end if;
         if Length (Error) = 0 then
            Read_Loop :
            loop
               declare
                  Count : constant Integer :=
                    Coyote_Image_IO.Read (File_FD, Buffer);
               begin
                  exit Read_Loop when Count = 0;
                  if Count < 0 then
                     Error := To_Unbounded_String ("Image read failed");
                     exit Read_Loop;
                  elsif Length (Data) + Count > Max_Source_Bytes then
                     Error :=
                       To_Unbounded_String
                         ("Image exceeds the 8 MiB size limit");
                     exit Read_Loop;
                  else
                     Append
                       (Data,
                        Buffer (Buffer'First .. Buffer'First + Count - 1));
                  end if;
               end;
            end loop Read_Loop;
            if Length (Error) = 0 then
               declare
                  Bytes : constant String := To_String (Data);
                  First : Natural         := Bytes'First;
               begin
                  while First <= Bytes'Last
                    and then
                    (Bytes (First) = ' ' or else Bytes (First) = ASCII.HT
                     or else Bytes (First) = ASCII.CR
                     or else Bytes (First) = ASCII.LF)
                  loop
                     First := First + 1;
                  end loop;
                  if First <= Bytes'Last and then Bytes (First) = '<' then
                     Error :=
                       To_Unbounded_String ("SVG images are not supported");
                  elsif Bytes'Length = 0 or else not Has_Signature (Bytes) then
                     Error :=
                       To_Unbounded_String
                         ("Image signature is not a supported raster format");
                  end if;
               end;
            end if;
         end if;
         if Length (Error) = 0 then
            Decoder := Coyote_Image_Decoder.New_Loader;
            if Coyote_Image_Decoder.Is_Null (Decoder) then
               Error :=
                 To_Unbounded_String ("Image decoder could not be created");
            else
               Size_State.Max_Width := Positive'Min (640, Width);
               Coyote_Image_Decoder.Connect_Size_Prepared
                 (Decoder,
                  On_Size_Prepared'Access,
                  Size_State'Unchecked_Access);
               begin
                  declare
                     Decode_Error : constant String :=
                       Coyote_Image_Decoder.Write (Decoder, To_String (Data));
                  begin
                     if Decode_Error'Length > 0 then
                        Error := To_Unbounded_String (Decode_Error);
                     end if;
                     if Size_State.Invalid then
                        Error :=
                          To_Unbounded_String
                            ("Image dimensions exceed the allowed limit");
                     end if;
                  end;
               exception
                  when others =>
                     if not Decoder_Closed then
                        declare
                           Close_Error : constant String :=
                             Coyote_Image_Decoder.Close (Decoder);
                           pragma Unreferenced (Close_Error);
                        begin
                           Decoder_Closed := True;
                        end;
                     end if;
                     raise;
               end;
               declare
                  Close_Error : constant String :=
                    Coyote_Image_Decoder.Close (Decoder);
               begin
                  Decoder_Closed := True;
                  if Length (Error) = 0 and then Close_Error'Length > 0 then
                     Error := To_Unbounded_String (Close_Error);
                  end if;
               end;
               if Size_State.Invalid then
                  Error :=
                    To_Unbounded_String
                      ("Image dimensions exceed the allowed limit");
               end if;
               if Length (Error) = 0 then
                  declare
                     Format : constant Coyote_Image_Decoder.Format_Handle :=
                       Coyote_Image_Decoder.Get_Format (Decoder);
                     Name   : constant String                             :=
                       Coyote_Image_Decoder.Format_Name (Format);
                  begin
                     if Name /= "png" and then Name /= "jpeg" then
                        Error :=
                          To_Unbounded_String
                            ("Only PNG and JPEG images are supported");
                     end if;
                  end;
               end if;
               if Length (Error) = 0 then
                  Pixbuf := Coyote_Image_Decoder.Get_Raw_Pixbuf (Decoder);
                  if Coyote_Image_Decoder.Is_Null (Pixbuf) then
                     Error :=
                       To_Unbounded_String ("Image decoder produced no image");
                  end if;
               end if;
            end if;
         end if;
      exception
         when E : others =>
            Error :=
              To_Unbounded_String
                ("Image decoding failed: "
                 & Ada.Exceptions.Exception_Name (E));
      end;
      if not Decoder_Closed and then not Coyote_Image_Decoder.Is_Null (Decoder)
      then
         declare
            Close_Error : constant String :=
              Coyote_Image_Decoder.Close (Decoder);
         begin
            Decoder_Closed := True;
            if Close_Error'Length > 0 and then Length (Error) = 0 then
               Error := To_Unbounded_String (Close_Error);
            end if;
         end;
      end if;
      Coyote_Image_Decoder.Free (Decoder);
      Coyote_Image_IO.Close (File_FD);
      Coyote_Image_IO.Close (Directory_FD);
      Coyote_Image_IO.Close (Root_FD);
      if Length (Error) > 0 and then not Coyote_Image_Decoder.Is_Null (Pixbuf)
      then
         Coyote_Image_Decoder.Release (Pixbuf);
      end if;
   exception
      when E : others =>
         Coyote_Image_Decoder.Free (Decoder);
         Coyote_Image_IO.Close (File_FD);
         Coyote_Image_IO.Close (Directory_FD);
         Coyote_Image_IO.Close (Root_FD);
         Coyote_Image_Decoder.Release (Pixbuf);
         Error :=
           To_Unbounded_String
             ("Image decoding failed: " & Ada.Exceptions.Exception_Name (E));
   end Load_Raw;

   procedure Load
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Gdk.Pixbuf.Gdk_Pixbuf;
      Error       : out Unbounded_String)
   is
      Raw : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
   begin
      Pixbuf := Gdk.Pixbuf.Null_Pixbuf;
      Load_Raw (Root, Destination, Width, Raw, Error);
      if Length (Error) = 0 then
         Pixbuf := Coyote_Image_Decoder.Adopt (Raw);
      end if;
      Coyote_Image_Decoder.Release (Raw);
   end Load;
end Coyote_Image_Loader;
