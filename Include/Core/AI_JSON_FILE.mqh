//+------------------------------------------------------------------+
//| AI_JSON_FILE.mqh                                                 |
//| JSON Parser for AI Integration                                   |
//+------------------------------------------------------------------+
#property copyright "2025, Advanced AI Trading Systems"
#property strict

#ifndef AI_JSON_FILE_MQH
#define AI_JSON_FILE_MQH

#define DEBUG_PRINT false

enum JsonValueType {JsonUndefined, JsonNull, JsonBoolean, JsonInteger, JsonDouble, JsonString, JsonArray, JsonObject};

class JsonValue {
public:
   JsonValue              m_children[];        //--- Array to hold child JSON values
   string                 m_key;               //--- Key for this JSON value
   string                 m_temporaryKey;      //--- Temporary key used during parsing
   JsonValue             *m_parent;            //--- Pointer to parent JSON value
   JsonValueType          m_type;              //--- Type of this JSON value
   bool                   m_booleanValue;      //--- Boolean value storage
   long                   m_integerValue;      //--- Integer value storage
   double                 m_doubleValue;       //--- Double value storage
   string                 m_stringValue;       //--- String value storage
   static int             encodingCodePage;    //--- Static code page for encoding

   JsonValue() { Reset(); }                    //--- Default constructor calls reset
   JsonValue(JsonValue *parent, JsonValueType type) { Reset(); m_type = type; m_parent = parent; } //--- Constructor with parent and type
   JsonValue(JsonValueType type, string value) { Reset(); SetFromString(type, value); } //--- Constructor with type and string value
   JsonValue(const int integerValue) { Reset(); m_type = JsonInteger; m_integerValue = integerValue; m_doubleValue = (double)m_integerValue; m_stringValue = IntegerToString(m_integerValue); m_booleanValue = m_integerValue != 0; } //--- Constructor from integer
   JsonValue(const JsonValue &other) { Reset(); CopyFrom(other); } //--- Copy constructor
   ~JsonValue() { Reset(); }                   //--- Destructor calls reset

   void Reset() {                              //--- Reset all members to default
      m_parent         = NULL;                 //--- Set parent to NULL
      m_key            = "";                   //--- Clear key
      m_temporaryKey   = "";                   //--- Clear temporary key
      m_type           = JsonUndefined;        //--- Set type to undefined
      m_booleanValue   = false;                //--- Set boolean to false
      m_integerValue   = 0;                    //--- Set integer to zero
      m_doubleValue    = 0;                    //--- Set double to zero
      m_stringValue    = "";                   //--- Clear string
      ArrayResize(m_children, 0);              //--- Resize children array to zero
   }

   bool CopyFrom(const JsonValue &source) {    //--- Copy from another JsonValue
      m_key            = source.m_key;         //--- Copy key
      CopyDataFrom(source);                    //--- Copy data
      return true;                             //--- Return success
   }

   void CopyDataFrom(const JsonValue &source) { //--- Copy core data from source
      m_type           = source.m_type;        //--- Copy type
      m_booleanValue   = source.m_booleanValue;//--- Copy boolean
      m_integerValue   = source.m_integerValue;//--- Copy integer
      m_doubleValue    = source.m_doubleValue; //--- Copy double
      m_stringValue    = source.m_stringValue; //--- Copy string
      CopyChildrenFrom(source);                //--- Copy children
   }

   void CopyChildrenFrom(const JsonValue &source) { //--- Copy children array from source
      int numChildren  = ArrayResize(m_children, ArraySize(source.m_children)); //--- Resize to match source
      for(int index = 0; index < numChildren; index++) { //--- Loop through children
         m_children[index] = source.m_children[index]; //--- Copy child
         m_children[index].m_parent = GetPointer(this); //--- Set parent to this
      }
   }

   JsonValue *FindChildByKey(string key) {     //--- Find child by key
      for(int index = ArraySize(m_children) - 1; index >= 0; --index) { //--- Search backwards
         if(m_children[index].m_key == key) return GetPointer(m_children[index]); //--- Return if found
      }
      return NULL;                             //--- Return NULL if not found
   }

   JsonValue *operator[](string key) {         //--- Access or create child by key
      if(m_type == JsonUndefined) m_type = JsonObject; //--- Set to object if undefined
      JsonValue *value = FindChildByKey(key);  //--- Find existing
      if(value) return value;                  //--- Return if exists
      JsonValue newValue(GetPointer(this), JsonUndefined); //--- Create new
      newValue.m_key = key;                    //--- Set key
      value = AddChildInternal(newValue);      //--- Add and return
      return value;                            //--- Return new value
   }

   JsonValue *operator[](int index) {          //--- Access or expand array by index
      if(m_type == JsonUndefined) m_type = JsonArray; //--- Set to array if undefined
      while(index >= ArraySize(m_children)) {  //--- Expand if needed
         JsonValue newValue(GetPointer(this), JsonUndefined); //--- Create new element
         if(CheckPointer(AddChildInternal(newValue)) == POINTER_INVALID) return NULL; //--- Add and check
      }
      return GetPointer(m_children[index]);    //--- Return element
   }

   void operator=(const JsonValue &value) { CopyFrom(value); } //--- Assignment from JsonValue

   void operator=(string stringValue) {        //--- Assignment from string
      m_type           = (stringValue != NULL) ? JsonString : JsonNull; //---
      m_stringValue    = stringValue;          //---
      m_integerValue   = StringToInteger(m_stringValue); //---
      m_doubleValue    = StringToDouble(m_stringValue); //---
      m_booleanValue   = stringValue != NULL;  //---
   }

   void operator=(const int integerValue) {    //--- Assignment from int
      m_type           = JsonInteger;          //---
      m_integerValue   = integerValue;         //---
      m_doubleValue    = (double)m_integerValue; //---
      m_stringValue    = IntegerToString(m_integerValue); //---
      m_booleanValue   = integerValue != 0;    //---
   }

   bool ToBoolean() const { return m_booleanValue; } //--- Convert to boolean
   string ToString() { return m_stringValue; } //--- Convert to string
   long ToInteger() const { return m_integerValue; } //--- Convert to integer
   double ToDouble() const { return m_doubleValue; } //--- Convert to double

   void SetFromString(JsonValueType type, string stringValue) { //--- Set value from string based on type
      m_type           = type;                 //--- Set type
      switch(m_type) {                         //--- Handle by type
         case JsonBoolean:                     //--- Boolean case
            m_booleanValue = (StringToInteger(stringValue) != 0); //--- Convert to bool
            m_integerValue = (long)m_booleanValue; //--- Set integer
            m_doubleValue  = (double)m_booleanValue; //--- Set double
            m_stringValue  = stringValue;        //--- Set string
            break;                               //--- Exit case
         case JsonString:                      //--- String case
            m_stringValue = UnescapeString(stringValue); //--- Unescape
            m_type        = (m_stringValue != NULL) ? JsonString : JsonNull; //--- Adjust type
            m_integerValue = StringToInteger(m_stringValue); //--- Set integer
            m_doubleValue  = StringToDouble(m_stringValue); //--- Set double
            m_booleanValue = m_stringValue != NULL; //--- Set boolean
            break;                               //--- Exit case
      }
   }

   string GetSubstringFromArray(char &jsonCharacterArray[], int startPosition, int substringLength) { //--- Get substring from char array
      if(substringLength <= 0) return "";      //--- Return empty if invalid length
      char temporaryArray[];                   //--- Temp array
      ArrayCopy(temporaryArray, jsonCharacterArray, 0, startPosition, substringLength); //--- Copy data
      return CharArrayToString(temporaryArray, 0, WHOLE_ARRAY, encodingCodePage); //--- Convert to string
   }

   JsonValue *AddChild(const JsonValue &item) { //--- Add child item
      if(m_type == JsonUndefined) m_type = JsonArray; //--- Set to array if undefined
      return AddChildInternal(item);           //--- Call internal add
   }

   JsonValue *AddChild(string stringValue) {   //--- Add string child
      JsonValue item(JsonString, stringValue); //---
      return AddChild(item);                   //---
   }

   JsonValue *AddChild(const int integerValue) { //--- Add int child
      JsonValue item(integerValue);            //---
      return AddChild(item);                   //---
   }

   JsonValue *AddChildInternal(const JsonValue &item) { //--- Internal add child
      int currentSize = ArraySize(m_children); //--- Get current size
      ArrayResize(m_children, currentSize + 1); //--- Resize
      m_children[currentSize] = item;          //--- Assign item
      m_children[currentSize].m_parent = GetPointer(this); //--- Set parent
      return GetPointer(m_children[currentSize]); //--- Return added
   }

   string SerializeToString() {                //--- Serialize to string
      string jsonString;                       //--- Declare string
      SerializeToString(jsonString);           //--- Call serialize
      return jsonString;                       //--- Return
   }

   void SerializeToString(string &jsonString, bool includeKey = false, bool includeComma = false) { //--- Serialize with options
      if(m_type == JsonUndefined) return;      //--- Skip if undefined
      if(includeComma) jsonString += ",";      //--- Add comma if needed
      if(includeKey) jsonString += StringFormat("\"%s\":", m_key); //--- Add key if needed
      int numChildren = ArraySize(m_children); //--- Get children count
      switch(m_type) {                         //--- Handle by type
         case JsonNull:    jsonString += "null"; break; //--- Null case
         case JsonBoolean: jsonString += (m_booleanValue ? "true" : "false"); break; //--- Boolean case
         case JsonInteger: jsonString += IntegerToString(m_integerValue); break; //--- Integer case
         case JsonDouble:  jsonString += DoubleToString(m_doubleValue); break; //--- Double case
         case JsonString: {                      //--- String case
            string escaped = EscapeString(m_stringValue); //--- Escape
            jsonString += (StringLen(escaped) > 0) ? StringFormat("\"%s\"", escaped) : "null"; //--- Append
         } break;                               //--- Exit case
         case JsonArray: {                       //--- Array case
            jsonString += "[";                   //--- Start array
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, false, index > 0); //--- Serialize children
            jsonString += "]";                   //--- End array
         } break;                               //--- Exit case
         case JsonObject: {                      //--- Object case
            jsonString += "{";                   //--- Start object
            for(int index = 0; index < numChildren; index++) m_children[index].SerializeToString(jsonString, true, index > 0); //--- Serialize children
            jsonString += "}";                   //--- End object
         } break;                               //--- Exit case
      }
   }

   bool DeserializeFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) { //--- Deserialize from array
      string validNumericCharacters = "0123456789+-.eE"; //--- Valid number chars
      int startPosition = currentIndex;         //--- Start position
      for(; currentIndex < arrayLength; currentIndex++) { //--- Loop array
         char currentCharacter = jsonCharacterArray[currentIndex]; //--- Current char
         if(currentCharacter == 0) break;       //--- Break on null
         switch(currentCharacter) {             //--- Switch on char
            case '\t': case '\r': case '\n': case ' ': startPosition = currentIndex + 1; break; //--- Skip whitespace
            case '[': {                          //--- Array start
               startPosition = currentIndex + 1; //--- Update start
               if(m_type != JsonUndefined) return false; //--- Type check
               m_type = JsonArray;                //--- Set array
               currentIndex++;                    //--- Increment
               JsonValue childValue(GetPointer(this), JsonUndefined); //--- Child value
               while(childValue.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) { //--- Loop children
                  if(childValue.m_type != JsonUndefined) AddChildInternal(childValue); //--- Add if defined
                  if(childValue.m_type == JsonInteger || childValue.m_type == JsonDouble || childValue.m_type == JsonArray) currentIndex++; //--- Adjust index
                  childValue.Reset();              //--- Reset child
                  childValue.m_parent = GetPointer(this); //--- Set parent
                  if(jsonCharacterArray[currentIndex] == ']') break; //--- End array
                  currentIndex++;                    //--- Increment
                  if(currentIndex >= arrayLength) return false; //--- Bounds check
               }
               return (jsonCharacterArray[currentIndex] == ']' || jsonCharacterArray[currentIndex] == 0); //--- Valid end
            }                                    //--- End array case
            case ']': return (m_parent && m_parent.m_type == JsonArray); //--- Array end
            case ':': {                          //--- Key separator
               if(m_temporaryKey == "") return false; //--- Key check
               JsonValue childValue(GetPointer(this), JsonUndefined); //--- New child
               JsonValue *addedChild = AddChildInternal(childValue); //--- Add
               addedChild.m_key = m_temporaryKey; //--- Set key
               m_temporaryKey = "";               //--- Clear temp
               currentIndex++;                    //--- Increment
               if(!addedChild.DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Recurse
            } break;                             //--- End key case
            case ',': {                          //--- Value separator
               startPosition = currentIndex + 1; //--- Update start
               if(!m_parent && m_type != JsonObject) return false; //--- Check context
               if(m_parent && m_parent.m_type != JsonArray && m_parent.m_type != JsonObject) return false; //--- Parent type
               if(m_parent && m_parent.m_type == JsonArray && m_type == JsonUndefined) return true; //--- Undefined in array
            } break;                             //--- End separator
            case '{': {                          //--- Object start
               startPosition = currentIndex + 1; //--- Update start
               if(m_type != JsonUndefined) return false; //--- Type check
               m_type = JsonObject;               //--- Set object
               currentIndex++;                    //--- Increment
               if(!DeserializeFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Recurse
               return (jsonCharacterArray[currentIndex] == '}' || jsonCharacterArray[currentIndex] == 0); //--- Valid end
            } break;                             //--- End object case
            case '}': return (m_type == JsonObject); //--- Object end
            case 't': case 'T': case 'f': case 'F': { //--- Boolean start
               if(m_type != JsonUndefined) return false; //--- Type check
               m_type = JsonBoolean;              //--- Set boolean
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "true", false) == 0) { //--- True check
                  m_booleanValue = true; currentIndex += 3; return true; //--- Set true
               }
               if(currentIndex + 4 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 5), "false", false) == 0) { //--- False check
                  m_booleanValue = false; currentIndex += 4; return true; //--- Set false
               }
               return false;                      //--- Invalid boolean
            } break;                             //--- End boolean
            case 'n': case 'N': {                //--- Null start
               if(m_type != JsonUndefined) return false; //--- Type check
               m_type = JsonNull;                 //--- Set null
               if(currentIndex + 3 < arrayLength && StringCompare(GetSubstringFromArray(jsonCharacterArray, currentIndex, 4), "null", false) == 0) { //--- Null check
                  currentIndex += 3; return true;  //--- Valid null
               }
               return false;                      //--- Invalid null
            } break;                             //--- End null
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
            case '-': case '+': case '.': {      //--- Number start
               if(m_type != JsonUndefined) return false; //--- Type check
               bool isDouble = false;             //--- Double flag
               int startOfNumber = currentIndex;  //--- Number start
               while(jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength) { //--- Parse number
                  currentIndex++;                  //--- Increment
                  if(StringFind(validNumericCharacters, GetSubstringFromArray(jsonCharacterArray, currentIndex, 1)) < 0) break; //--- Invalid char
                  if(!isDouble) isDouble = (jsonCharacterArray[currentIndex] == '.' || jsonCharacterArray[currentIndex] == 'e' || jsonCharacterArray[currentIndex] == 'E'); //--- Set double
               }
               m_stringValue = GetSubstringFromArray(jsonCharacterArray, startOfNumber, currentIndex - startOfNumber); //--- Get string
               if(isDouble) {                     //--- Double handling
                  m_type        = JsonDouble;      //--- Set type
                  m_doubleValue = StringToDouble(m_stringValue); //--- Convert double
                  m_integerValue = (long)m_doubleValue; //--- Set integer
                  m_booleanValue = m_integerValue != 0; //--- Set boolean
               } else {                           //--- Integer handling
                  m_type        = JsonInteger;     //--- Set type
                  m_integerValue = StringToInteger(m_stringValue); //--- Convert integer
                  m_doubleValue  = (double)m_integerValue; //--- Set double
                  m_booleanValue = m_integerValue != 0; //--- Set boolean
               }
               currentIndex--;                    //--- Adjust index
               return true;                       //--- Success
            } break;                             //--- End number
            case '\"': {                         //--- String or key start
               if(m_type == JsonObject) {         //--- Key in object
                  currentIndex++;                  //--- Increment
                  int startOfString = currentIndex;//--- String start
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Extract
                  m_temporaryKey = GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString); //--- Set temp key
               } else {                           //--- Value string
                  if(m_type != JsonUndefined) return false; //--- Type check
                  m_type = JsonString;             //--- Set string
                  currentIndex++;                  //--- Increment
                  int startOfString = currentIndex;//--- String start
                  if(!ExtractStringFromArray(jsonCharacterArray, arrayLength, currentIndex)) return false; //--- Extract
                  SetFromString(JsonString, GetSubstringFromArray(jsonCharacterArray, startOfString, currentIndex - startOfString)); //--- Set value
                  return true;                     //--- Success
               }
            } break;                             //--- End string
         }
      }
      return true;                             //--- Default success
   }

   bool ExtractStringFromArray(char &jsonCharacterArray[], int arrayLength, int &currentIndex) { //--- Extract string handling escapes
      for(; jsonCharacterArray[currentIndex] != 0 && currentIndex < arrayLength; currentIndex++) { //--- Loop string
         char currentCharacter = jsonCharacterArray[currentIndex]; //--- Current
         if(currentCharacter == '\"') break;    //--- End on quote
         if(currentCharacter == '\\' && currentIndex + 1 < arrayLength) { //--- Escape
            currentIndex++;                      //--- Increment
            currentCharacter = jsonCharacterArray[currentIndex]; //--- Escaped char
            switch(currentCharacter) {           //--- Handle escape
               case '/': case '\\': case '\"': case 'b': case 'f': case 'r': case 'n': case 't': break; //--- Standard
               case 'u': {                        //--- Unicode
                  currentIndex++;                  //--- Increment
                  for(int hexIndex = 0; hexIndex < 4 && currentIndex < arrayLength && jsonCharacterArray[currentIndex] != 0; hexIndex++, currentIndex++) { //--- Hex loop
                     if(!((jsonCharacterArray[currentIndex] >= '0' && jsonCharacterArray[currentIndex] <= '9') || (jsonCharacterArray[currentIndex] >= 'A' && jsonCharacterArray[currentIndex] <= 'F') || (jsonCharacterArray[currentIndex] >= 'a' && jsonCharacterArray[currentIndex] <= 'f'))) return false; //--- Valid hex check
                  }
                  currentIndex--;                   //--- Adjust
                  break;                            //--- End unicode
               }
               default: break;                    //--- Other
            }
         }
      }
      return true;                             //--- Success
   }

   string EscapeString(string value) {         //--- Escape string
      ushort inputCharacters[], escapedCharacters[]; //--- Arrays
      int inputLength = StringToShortArray(value, inputCharacters); //--- To short array
      if(ArrayResize(escapedCharacters, 2 * inputLength) != 2 * inputLength) return NULL; //--- Resize check
      int escapedIndex = 0;                    //--- Escaped index
      for(int inputIndex = 0; inputIndex < inputLength; inputIndex++) { //--- Loop input
         switch(inputCharacters[inputIndex]) {  //--- Special chars
            case '\\': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '\\'; escapedIndex++; break; //--- Backslash
            case '"':  escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '"'; escapedIndex++; break; //--- Quote
            case '/':  escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = '/'; escapedIndex++; break; //--- Slash
            case 8:    escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'b'; escapedIndex++; break; //--- Backspace
            case 12:   escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'f'; escapedIndex++; break; //--- Form feed
            case '\n': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'n'; escapedIndex++; break; //--- Newline
            case '\r': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 'r'; escapedIndex++; break; //--- Carriage return
            case '\t': escapedCharacters[escapedIndex] = '\\'; escapedIndex++; escapedCharacters[escapedIndex] = 't'; escapedIndex++; break; //--- Tab
            default:   escapedCharacters[escapedIndex] = inputCharacters[inputIndex]; escapedIndex++; break; //--- Normal
         }
      }
      return ShortArrayToString(escapedCharacters, 0, escapedIndex); //--- To string
   }

   string UnescapeString(string value) {        //--- Unescape string
      ushort inputCharacters[], unescapedCharacters[]; //--- Arrays
      int inputLength = StringToShortArray(value, inputCharacters); //--- To short array
      if(ArrayResize(unescapedCharacters, inputLength) != inputLength) return NULL; //--- Resize check
      int outputIndex = 0, inputIndex = 0;      //--- Indices
      while(inputIndex < inputLength) {          //--- Loop input
         ushort currentCharacter = inputCharacters[inputIndex]; //--- Current
         if(currentCharacter == '\\' && inputIndex < inputLength - 1) { //--- Escape
            switch(inputCharacters[inputIndex + 1]) { //--- Handle
               case '\\': currentCharacter = '\\'; inputIndex++; break; //--- Backslash
               case '"':  currentCharacter = '"'; inputIndex++; break; //--- Quote
               case '/':  currentCharacter = '/'; inputIndex++; break; //--- Slash
               case 'b':  currentCharacter = 8; inputIndex++; break; //--- Backspace
               case 'f':  currentCharacter = 12; inputIndex++; break; //--- Form feed
               case 'n':  currentCharacter = '\n'; inputIndex++; break; //--- Newline
               case 'r':  currentCharacter = '\r'; inputIndex++; break; //--- Carriage return
               case 't':  currentCharacter = '\t'; inputIndex++; break; //--- Tab
            }
         }
         unescapedCharacters[outputIndex] = currentCharacter; //--- Copy
         outputIndex++;                           //--- Increment output
         inputIndex++;                            //--- Increment input
      }
      return ShortArrayToString(unescapedCharacters, 0, outputIndex); //--- To string
   }
};
int JsonValue::encodingCodePage = CP_UTF8;
#endif // AI_JSON_FILE_MQH
