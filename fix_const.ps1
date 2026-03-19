$Code = Get-Content lib/features/product/presentation/pages/product_list_page.dart -Raw
$Code = $Code -replace 'return const Center\(', 'return Center('
Set-Content "lib/features/product/presentation/pages/product_list_page.dart" $Code
