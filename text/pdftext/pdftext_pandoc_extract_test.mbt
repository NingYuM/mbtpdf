///|
async test "extract text pandoc basic fixture" {
  let pdf = @pdfread.pdf_of_file(None, None, "testdata/pandoc/pandoc_basic.pdf")
  let pages = @pdftext.extract_text_by_page(pdf)
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
  let pdf = @pdfread.pdf_of_file(
    None,
    None,
    "testdata/pandoc/pandoc_unicode.pdf",
  )
  let extracted = @pdftext.extract_text(pdf)
  debug_inspect(
    extracted,
    content=(
      #|"PandocFixtureUnicode\nPandocUnicodePage\nWords:Café,naïve,Español,£pound,€euro,Ωmega.\nChinese:中文测试\n1"
    ),
  )
}
