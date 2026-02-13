package csv

import (
	"encoding/csv"
	"io"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

type TestParser1 struct {
	Field1 string `csv:"field1"`
	Field2 int    `csv:"field2"`
	TestParser2
}

type TestParser2 struct {
	Field3 string `csv:"field3"`
}

type TestParser3 struct {
	Field1 int `csv:"field1"`
	testParser4
}

type testParser4 struct {
	Field2 string `csv:"field2"`
}

type TestParserAllTypes struct {
	StringField  string  `csv:"string_field"`
	IntField     int     `csv:"int_field"`
	BoolField    bool    `csv:"bool_field"`
	Float32Field float32 `csv:"float32_field"`
	Float64Field float64 `csv:"float64_field"`
}

type TestParserSkipField struct {
	Field1       string `csv:"field1"`
	SkippedField string
	Field2       int `csv:"field2"`
}

type TestParserNonStruct struct {
	Value string
}

type TestParserNestedError struct {
	Field1 string `csv:"field1"`
	Nested TestParserWithIntError
}

type TestParserWithIntError struct {
	Field2 int `csv:"field2"`
}

func TestParser(t *testing.T) {
	newParser, _ := NewCSVStructer(&TestParser1{}, []string{"field1", "field2", "field3"})
	isValid := newParser.ValidateHeaders([]string{"field1", "field2", "field3"})
	assert.Equal(t, isValid, true)
	var parser TestParser1
	err := newParser.ScanStruct([]string{"apple", "43", "banana"}, &parser)
	assert.Nil(t, err)
	assert.Equal(t, parser.Field1, "apple")
	assert.Equal(t, parser.Field2, 43)
	assert.Equal(t, parser.Field3, "banana")
}

func TestParser_Error(t *testing.T) {
	newParser, err := NewCSVStructer(&TestParser1{}, []string{"field1", "field2"})
	assert.Nil(t, err)
	isValid := newParser.ValidateHeaders([]string{"field3", "field2"})
	assert.Equal(t, isValid, false)
	var parser TestParser1
	err = newParser.ScanStruct([]string{"apple", "banana"}, &parser)
	assert.Error(t, err)
}

func TestParser_UnexportedFields(t *testing.T) {
	newParser, err := NewCSVStructer(&TestParser3{}, []string{"field1", "field2"})
	assert.Nil(t, err)
	isValid := newParser.ValidateHeaders([]string{"field1", "field2"})
	assert.Equal(t, isValid, true)
	var parser TestParser3
	err = newParser.ScanStruct([]string{"10", "banana"}, &parser)
	assert.Error(t, err)
	assert.Equal(t, err.Error(), "struct contains unexported fields")
}

func TestParser_FromCSVFile(t *testing.T) {
	file, err := os.Open("test.csv")
	assert.Nil(t, err)
	defer file.Close()

	reader := csv.NewReader(file)
	headers, err := reader.Read()
	assert.Nil(t, err)

	newParser, err := NewCSVStructer(&TestParser1{}, headers)
	assert.Nil(t, err)
	assert.True(t, newParser.ValidateHeaders(headers))

	var parsers []TestParser1
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		assert.Nil(t, err)

		var parser TestParser1
		err = newParser.ScanStruct(record, &parser)
		assert.Nil(t, err)
		parsers = append(parsers, parser)
	}

	assert.Equal(t, 4, len(parsers))
	assert.Equal(t, "apple", parsers[0].Field1)
	assert.Equal(t, 43, parsers[0].Field2)
	assert.Equal(t, "banana", parsers[0].Field3)
	assert.Equal(t, "orange", parsers[1].Field1)
	assert.Equal(t, 25, parsers[1].Field2)
	assert.Equal(t, "grape", parsers[1].Field3)
}

func TestParser_AllTypes(t *testing.T) {
	headers := []string{"string_field", "int_field", "bool_field", "float32_field", "float64_field"}
	newParser, err := NewCSVStructer(&TestParserAllTypes{}, headers)
	assert.Nil(t, err)
	assert.True(t, newParser.ValidateHeaders(headers))

	var parser TestParserAllTypes
	err = newParser.ScanStruct([]string{"test", "123", "true", "3.14", "2.71828"}, &parser)
	assert.Nil(t, err)
	assert.Equal(t, "test", parser.StringField)
	assert.Equal(t, 123, parser.IntField)
	assert.Equal(t, true, parser.BoolField)
	assert.Equal(t, float32(3.14), parser.Float32Field)
	assert.Equal(t, 2.71828, parser.Float64Field)
}

func TestParser_BoolParseError(t *testing.T) {
	headers := []string{"string_field", "int_field", "bool_field", "float32_field", "float64_field"}
	newParser, _ := NewCSVStructer(&TestParserAllTypes{}, headers)
	var parser TestParserAllTypes
	err := newParser.ScanStruct([]string{"test", "123", "invalid_bool", "3.14", "2.71"}, &parser)
	assert.Error(t, err)
}

func TestParser_Float32ParseError(t *testing.T) {
	headers := []string{"string_field", "int_field", "bool_field", "float32_field", "float64_field"}
	newParser, _ := NewCSVStructer(&TestParserAllTypes{}, headers)
	var parser TestParserAllTypes
	err := newParser.ScanStruct([]string{"test", "123", "true", "invalid_float", "2.71"}, &parser)
	assert.Error(t, err)
}

func TestParser_Float64ParseError(t *testing.T) {
	headers := []string{"string_field", "int_field", "bool_field", "float32_field", "float64_field"}
	newParser, _ := NewCSVStructer(&TestParserAllTypes{}, headers)
	var parser TestParserAllTypes
	err := newParser.ScanStruct([]string{"test", "123", "true", "3.14", "invalid_float"}, &parser)
	assert.Error(t, err)
}

func TestParser_SkipFieldWithoutTag(t *testing.T) {
	headers := []string{"field1", "field2"}
	newParser, err := NewCSVStructer(&TestParserSkipField{}, headers)
	assert.Nil(t, err)

	var parser TestParserSkipField
	err = newParser.ScanStruct([]string{"value1", "42"}, &parser)
	assert.Nil(t, err)
	assert.Equal(t, "value1", parser.Field1)
	assert.Equal(t, 42, parser.Field2)
	assert.Equal(t, "", parser.SkippedField) // Should remain empty
}

func TestParser_NonPointerInput(t *testing.T) {
	headers := []string{"field1"}
	newParser, _ := NewCSVStructer(&TestParser1{}, headers)
	var parser TestParser1
	err := newParser.ScanStruct([]string{"value"}, parser) // Not a pointer
	assert.Error(t, err)
	assert.Equal(t, "input should be a pointer to a struct", err.Error())
}

func TestParser_PointerToNonStruct(t *testing.T) {
	headers := []string{"field1"}
	newParser, _ := NewCSVStructer(&TestParser1{}, headers)
	var value string = "test"
	err := newParser.ScanStruct([]string{"value"}, &value) // Pointer to string, not struct
	assert.Error(t, err)
	assert.Equal(t, "input should be a pointer to a struct", err.Error())
}

func TestValidateHeaders_DifferentLength(t *testing.T) {
	newParser, _ := NewCSVStructer(&TestParser1{}, []string{"field1", "field2", "field3"})
	isValid := newParser.ValidateHeaders([]string{"field1", "field2"}) // Too few
	assert.False(t, isValid)

	isValid = newParser.ValidateHeaders([]string{"field1", "field2", "field3", "field4"}) // Too many
	assert.False(t, isValid)
}

func TestParser_NestedStructParseError(t *testing.T) {
	headers := []string{"field1", "field2"}
	newParser, _ := NewCSVStructer(&TestParserNestedError{}, headers)
	var parser TestParserNestedError
	err := newParser.ScanStruct([]string{"value1", "not_a_number"}, &parser)
	assert.Error(t, err) // This should trigger error return in nested struct scanning
}
