///|
async test "extract text pandoc basic fixture" {
  let pdf = @pdfread.PdfRead::new().pdf_of_file(
    None,
    None,
    "testdata/pandoc/pandoc_basic.pdf",
  )
  let pages = @pdftext.PdfText::new(pdf).extract_text_by_page()
  debug_inspect(
    pages,
    content=(
      #|[
      #|  "PandocFixtureBasic\nPandocFixturePageOne\nThisfixturecheckssimpleASCIItokens.\n•\nAlphaTokenOne\n•\nBetaTokenTwo\n1",
      #|  "PandocFixturePageTwo\nSecondpagewithnumbers12345andMixedCaseToken.\n2",
      #|]
    ),
  )
}

///|
async test "extract text pandoc unicode fixture" {
  let pdf = @pdfread.PdfRead::new().pdf_of_file(
    None,
    None,
    "testdata/pandoc/pandoc_unicode.pdf",
  )
  let extracted = @pdftext.PdfText::new(pdf).extract_text()
  debug_inspect(
    extracted,
    content=(
      #|"PandocFixtureUnicode\nPandocUnicodePage\nWords:Café,naïve,Español,£pound,€euro,Ωmega.\nChinese:中文测试\n1"
    ),
  )
}
