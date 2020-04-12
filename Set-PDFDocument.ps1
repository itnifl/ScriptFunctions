function Set-PDFDocument {
	<#
    .SYNOPSIS 
		Writes a pdf document
    .EXAMPLE
		Set-PDFDocument -Title "Title goes here" -Heading "This is the page header" -Filename "D:\pdfs\myFile.pdf" -Body "This is where the text goes." -PdfPluginPath "D:\PowerShellAddons\PdfSharp.dll"
	#>
	param(
		[alias("Title")] [Parameter(Mandatory=$True,Position=0)] [String] $strTitle,
		[alias("Heading")] [Parameter(Mandatory=$True,Position=1)] [String] $strHeading,
		[alias("Filename")] [Parameter(Mandatory=$True,Position=2)] [String] $strFilename,
		[alias("Body")] [Parameter(Mandatory=$True,Position=3)] [String] $strMessageBody,
		[alias("PdfPluginPath")] [Parameter(Mandatory=$True,Position=4)] [String] $strPdfSharpPath
	)
	Add-Type -Path $strPdfSharpPath
	$doc = New-Object PdfSharp.Pdf.PdfDocument
	$doc.Info.Title = $strTitle;
	$page = $doc.AddPage();
	$gfx = [PdfSharp.Drawing.XGraphics]::FromPdfPage($page)
	$tf = New-Object PdfSharp.Drawing.Layout.XTextFormatter($gfx);
	$fontHeader = New-Object PdfSharp.Drawing.XFont("Copperplate Gothic", 22, [PdfSharp.Drawing.XFontStyle]::Bold)
	$fontBody = New-Object PdfSharp.Drawing.XFont("Arial", 12, [PdfSharp.Drawing.XFontStyle]::Regular)
	$rectHeading = New-Object PdfSharp.Drawing.XRect(0,0,$page.Width, 50)
	$rectBody = New-Object PdfSharp.Drawing.XRect(0,51,$page.Width, $page.Height)
	$gfx.DrawString($strHeading, $fontHeader, [PdfSharp.Drawing.XBrushes]::Black, $rectHeading, [PdfSharp.Drawing.XStringFormats]::TopCenter)
	$tf.DrawString($strMessageBody, $fontBody, [PdfSharp.Drawing.XBrushes]::Black, $rectBody, [PdfSharp.Drawing.XStringFormats]::TopLeft)
	$doc.Save($strFilename);
}