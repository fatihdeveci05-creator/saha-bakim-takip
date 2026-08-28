import ExcelJS from 'exceljs'

export interface ExcelSheet {
  name: string
  headers: string[]
  rows: (string | number | null)[][]
}

export async function downloadExcel(filename: string, sheets: ExcelSheet[]) {
  const workbook = new ExcelJS.Workbook()

  for (const sheet of sheets) {
    const ws = workbook.addWorksheet(sheet.name)
    ws.addRow(sheet.headers)
    ws.getRow(1).font = { bold: true }
    for (const row of sheet.rows) {
      ws.addRow(row.map((v) => v ?? ''))
    }
    ws.columns.forEach((col) => {
      let maxLen = 10
      col.eachCell?.({ includeEmpty: true }, (cell) => {
        maxLen = Math.max(maxLen, String(cell.value ?? '').length + 2)
      })
      col.width = Math.min(maxLen, 40)
    })
  }

  const buffer = await workbook.xlsx.writeBuffer()
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
