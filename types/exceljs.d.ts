declare module "@excel.js/exceljs" {
  export interface Cell {
    value: unknown;
  }

  export interface Row {
    values: unknown[] | Record<string, unknown>;
    getCell(index: number): Cell;
  }

  export interface Worksheet {
    rowCount: number;
    getRow(index: number): Row;
  }

  export class Workbook {
    xlsx: {
      load(data: ArrayBuffer): Promise<Workbook>;
    };
    worksheets: Worksheet[];
  }
}
