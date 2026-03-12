package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"

	csvtostruct "github.com/AndriyKalashnykov/csvtostruct"
)

type Record struct {
	Name  string  `csv:"name"`
	Age   int     `csv:"age"`
	Score float64 `csv:"score"`
}

func main() {
	file, err := os.Open("test.csv")
	if err != nil {
		fmt.Println("error opening file:", err)
		return
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Read the header row
	headers, err := reader.Read()
	if err != nil {
		fmt.Println("error reading headers:", err)
		return
	}

	// Create a parser and validate headers
	parser, err := csvtostruct.NewCSVStructer(&Record{}, headers)
	if err != nil {
		fmt.Println("error creating parser:", err)
		return
	}
	if !parser.ValidateHeaders(headers) {
		fmt.Println("CSV headers do not match struct tags")
		return
	}

	// Read and parse each data row
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Println("error reading record:", err)
			continue
		}

		var r Record
		if err := parser.ScanStruct(record, &r); err != nil {
			fmt.Println("parse error:", err)
			continue
		}
		fmt.Printf("%+v\n", r)
	}
}
