[CmdletBinding()]
param(
    [string]$DatabasePath = 'C:\Mercader\Mods\DAT_PV.accdb',
    [string]$OutputDir = 'C:\Mercader\Mods\access_audit_out'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$queriesDir = Join-Path $OutputDir 'queries'
$formsDir = Join-Path $OutputDir 'forms'
$reportsDir = Join-Path $OutputDir 'reports'
$ribbonDir = Join-Path $OutputDir 'ribbon'
$vbaDir = Join-Path $OutputDir 'vba_export'
$runLogPath = Join-Path $OutputDir 'run.log'

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$ts][$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $script:runLogPath -Value $line -Encoding UTF8
}

function Convert-ToSafeFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'unnamed' }
    $safe = $Name.Trim()
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$ch, '_')
    }
    if ($safe.Length -gt 120) { $safe = $safe.Substring(0, 120) }
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'unnamed' }
    return $safe
}

function Save-JsonFile {
    param([object]$Data, [string]$Path, [int]$Depth = 50)
    $json = $Data | ConvertTo-Json -Depth $Depth
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Normalize-CallbackName {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()
    if ($v.StartsWith('=')) { $v = $v.Substring(1).Trim() }
    $v = $v -replace '\(\s*\)\s*$', ''
    if ($v -match '^([A-Za-z_][A-Za-z0-9_]*)$') { return $Matches[1] }
    return $null
}

function Get-DaoDataTypeName {
    param([int]$TypeCode)
    switch ($TypeCode) {
        1 { 'Boolean' }
        2 { 'Byte' }
        3 { 'Integer' }
        4 { 'Long' }
        5 { 'Currency' }
        6 { 'Single' }
        7 { 'Double' }
        8 { 'DateTime' }
        9 { 'Binary' }
        10 { 'Text' }
        11 { 'LongBinary' }
        12 { 'Memo' }
        15 { 'GUID' }
        16 { 'BigInt' }
        17 { 'VarBinary' }
        18 { 'Char' }
        19 { 'Numeric' }
        20 { 'Decimal' }
        default { "TypeCode_$TypeCode" }
    }
}

function Parse-SqlDependencies {
    param([string]$Sql)
    $deps = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ([string]::IsNullOrWhiteSpace($Sql)) { return @() }
    $clean = $Sql -replace '[\r\n\t]+', ' '
    $pattern = '(?i)\b(?:FROM|JOIN|UPDATE|INTO|DELETE\s+FROM)\s+((?:\[[^\]]+\]|[A-Za-z_][A-Za-z0-9_\.\$#]*))'
    foreach ($m in [regex]::Matches($clean, $pattern)) {
        $name = $m.Groups[1].Value.Trim().Trim('[', ']')
        if ($name.Contains('.')) { $name = $name.Split('.')[-1].Trim('[', ']') }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match '^(?i)(SELECT|INNER|LEFT|RIGHT|FULL|WHERE|ORDER|GROUP|HAVING|ON|AS)$') { continue }
        [void]$deps.Add($name)
    }
    return @($deps | Sort-Object)
}

function Parse-RibbonXml {
    param([string]$RibbonName, [string]$XmlText)
    [xml]$doc = $XmlText
    $tabs = New-Object System.Collections.Generic.List[object]
    $groups = New-Object System.Collections.Generic.List[object]
    $controls = New-Object System.Collections.Generic.List[object]
    $callbacks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $controlTags = @('button', 'toggleButton', 'checkBox', 'editBox', 'dropDown', 'comboBox', 'gallery', 'menu', 'splitButton', 'dynamicMenu', 'menuSeparator', 'control')

    foreach ($node in $doc.SelectNodes('//*')) {
        $local = [string]$node.LocalName
        $attrs = @{}
        if ($node.Attributes) {
            foreach ($attr in $node.Attributes) {
                $attrs[$attr.Name] = [string]$attr.Value
                if ($attr.Name -eq 'onAction' -or $attr.Name -eq 'onLoad' -or $attr.Name -like 'get*') {
                    if (-not [string]::IsNullOrWhiteSpace([string]$attr.Value)) {
                        [void]$callbacks.Add([string]$attr.Value)
                    }
                }
            }
        }
        if ($local -eq 'tab') {
            $tabs.Add([ordered]@{ id = $attrs['id']; idMso = $attrs['idMso']; label = $attrs['label'] })
            continue
        }
        if ($local -eq 'group') {
            $groups.Add([ordered]@{ id = $attrs['id']; idMso = $attrs['idMso']; label = $attrs['label'] })
            continue
        }
        if ($controlTags -contains $local) {
            $controls.Add([ordered]@{
                    type = $local
                    id = $attrs['id']
                    idMso = $attrs['idMso']
                    label = $attrs['label']
                    onAction = $attrs['onAction']
                })
        }
    }

    return [ordered]@{
        ribbonName = $RibbonName
        tabs = $tabs.ToArray()
        groups = $groups.ToArray()
        controls = $controls.ToArray()
        callbacks = @($callbacks | Sort-Object -Unique)
    }
}

function Parse-RibbonXmlFallback {
    param([string]$RibbonName, [string]$XmlText)
    function Get-Attr {
        param([string]$Text, [string]$AttrName)
        $m = [regex]::Match($Text, "(?is)\b$AttrName\s*=\s*""([^""]*)""")
        if ($m.Success) { return $m.Groups[1].Value }
        return $null
    }
    $tabs = New-Object System.Collections.Generic.List[object]
    $groups = New-Object System.Collections.Generic.List[object]
    $controls = New-Object System.Collections.Generic.List[object]
    $callbacks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($m in [regex]::Matches($XmlText, '(?is)<tab\b([^>]*)>')) {
        $a = [string]$m.Groups[1].Value
        $tabs.Add([ordered]@{ id = (Get-Attr $a 'id'); idMso = (Get-Attr $a 'idMso'); label = (Get-Attr $a 'label') })
    }
    foreach ($m in [regex]::Matches($XmlText, '(?is)<group\b([^>]*)>')) {
        $a = [string]$m.Groups[1].Value
        $groups.Add([ordered]@{ id = (Get-Attr $a 'id'); idMso = (Get-Attr $a 'idMso'); label = (Get-Attr $a 'label') })
    }
    foreach ($m in [regex]::Matches($XmlText, '(?is)<(button|toggleButton|checkBox|editBox|dropDown|comboBox|gallery|menu|splitButton|dynamicMenu|control)\b([^>]*)>')) {
        $type = [string]$m.Groups[1].Value
        $a = [string]$m.Groups[2].Value
        $onAction = Get-Attr $a 'onAction'
        if (-not [string]::IsNullOrWhiteSpace($onAction)) { [void]$callbacks.Add($onAction) }
        $controls.Add([ordered]@{
                type = $type
                id = (Get-Attr $a 'id')
                idMso = (Get-Attr $a 'idMso')
                label = (Get-Attr $a 'label')
                onAction = $onAction
            })
    }
    foreach ($m in [regex]::Matches($XmlText, '(?is)\bonAction\s*=\s*"([^"]+)"')) { [void]$callbacks.Add([string]$m.Groups[1].Value) }

    return [ordered]@{
        ribbonName = $RibbonName
        tabs = $tabs.ToArray()
        groups = $groups.ToArray()
        controls = $controls.ToArray()
        callbacks = @($callbacks | Sort-Object -Unique)
    }
}

function Get-AccessObjectNames {
    param($Collection)
    $names = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Collection) { return @() }
    try {
        foreach ($obj in $Collection) {
            $name = $null
            try { $name = [string]$obj.Name } catch { $name = [string]$obj }
            if (-not [string]::IsNullOrWhiteSpace($name)) { $names.Add($name) }
        }
    }
    catch { }
    if ($names.Count -eq 0) {
        try {
            $count = [int]$Collection.Count
            for ($i = 0; $i -lt $count; $i++) {
                $item = $null
                try { $item = $Collection.Item($i) } catch { try { $item = $Collection.Item($i + 1) } catch { $item = $null } }
                if ($null -eq $item) { continue }
                $name = $null
                try { $name = [string]$item.Name } catch { $name = [string]$item }
                if (-not [string]::IsNullOrWhiteSpace($name)) { $names.Add($name) }
            }
        }
        catch { }
    }
    return @($names | Sort-Object -Unique)
}

function Get-DaoContainerNames {
    param($Db, [string]$ContainerName)
    $names = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Db) { return @() }
    try {
        $container = $Db.Containers[$ContainerName]
        foreach ($doc in $container.Documents) {
            $name = $null
            try { $name = [string]$doc.Name } catch { $name = $null }
            if (-not [string]::IsNullOrWhiteSpace($name)) { $names.Add($name) }
        }
    }
    catch { }
    return @($names | Sort-Object -Unique)
}

function Parse-SaveAsTextMetadata {
    param(
        [string]$Text,
        [string]$ObjectName,
        [ValidateSet('Form', 'Report')][string]$ObjectType,
        [System.Collections.Generic.HashSet[string]]$KnownQueries,
        [System.Collections.Generic.HashSet[string]]$KnownTables
    )
    $recordSource = $null
    $mRecord = [regex]::Match($Text, '(?im)^\s*RecordSource\s*=\s*"?([^"\r\n]*)"?\s*$')
    if ($mRecord.Success) { $recordSource = $mRecord.Groups[1].Value.Trim() }

    $rowSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in [regex]::Matches($Text, '(?im)^\s*RowSource\s*=\s*"?([^"\r\n]*)"?\s*$')) {
        $v = $m.Groups[1].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($v)) { [void]$rowSet.Add($v) }
    }

    $events = New-Object System.Collections.Generic.List[object]
    $procHints = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in [regex]::Matches($Text, '(?im)^\s*(OnOpen|OnLoad|OnCurrent|OnClick|OnClose)\s*=\s*"?([^"\r\n]*)"?\s*$')) {
        $evt = $m.Groups[1].Value.Trim()
        $val = $m.Groups[2].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($val)) { continue }
        $events.Add([ordered]@{ event = $evt; value = $val })
        if ($val -eq '[Event Procedure]') {
            $prefix = if ($ObjectType -eq 'Form') { 'Form' } else { 'Report' }
            switch ($evt) {
                'OnOpen' { [void]$procHints.Add("${prefix}_Open") }
                'OnLoad' { [void]$procHints.Add("${prefix}_Load") }
                'OnCurrent' { [void]$procHints.Add("${prefix}_Current") }
                'OnClick' { [void]$procHints.Add("${prefix}_Click") }
                'OnClose' { [void]$procHints.Add("${prefix}_Close") }
            }
        }
        else {
            $p = Normalize-CallbackName -Value $val
            if ($null -ne $p) { [void]$procHints.Add($p) }
        }
    }

    $refs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $sources = @()
    if (-not [string]::IsNullOrWhiteSpace($recordSource)) { $sources += $recordSource }
    $sources += @($rowSet)
    foreach ($src in $sources) {
        $v = [string]$src
        if ($v -match '^(?i)SELECT\b') {
            foreach ($dep in Parse-SqlDependencies -Sql $v) { [void]$refs.Add($dep) }
        }
        else {
            $cand = $v.Trim('[', ']')
            if ($KnownQueries.Contains($cand) -or $KnownTables.Contains($cand)) { [void]$refs.Add($cand) }
        }
    }

    return [ordered]@{
        name = $ObjectName
        objectType = $ObjectType
        recordSource = $recordSource
        rowSources = @($rowSet | Sort-Object)
        events = $events.ToArray()
        procedureHints = @($procHints | Sort-Object)
        queryOrTableRefs = @($refs | Sort-Object)
    }
}

function Get-UniqueMatches {
    param([string]$Text, [string]$Pattern, [int]$Group = 1)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($m in [regex]::Matches($Text, $Pattern)) {
        $v = $m.Groups[$Group].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($v)) { [void]$set.Add($v) }
    }
    return @($set | Sort-Object)
}

function Parse-VbaProceduresFromFile {
    param([string]$FilePath, [string]$ModuleName)
    $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    $starts = [regex]::Matches($content, '(?im)^\s*(?:Public|Private|Friend)?\s*(?:Static\s+)?(?:Sub|Function)\s+([A-Za-z_][A-Za-z0-9_]*)\b')
    $list = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $starts.Count; $i++) {
        $name = $starts[$i].Groups[1].Value.Trim()
        $from = $starts[$i].Index
        $to = if ($i -lt ($starts.Count - 1)) { $starts[$i + 1].Index } else { $content.Length }
        $body = $content.Substring($from, [Math]::Max(0, $to - $from))
        $qRefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($q in Get-UniqueMatches -Text $body -Pattern '(?im)\bDoCmd\.OpenQuery\s*\(\s*"([^"]+)"') { [void]$qRefs.Add($q) }
        foreach ($q in Get-UniqueMatches -Text $body -Pattern '(?im)\bQueryDefs\s*\(\s*"([^"]+)"') { [void]$qRefs.Add($q) }
        foreach ($arg in Get-UniqueMatches -Text $body -Pattern '(?im)\b(?:CurrentDb\(\)\.)?OpenRecordset\s*\(\s*"([^"]+)"') {
            if ($arg -match '^(?i)SELECT\b') {
                foreach ($dep in Parse-SqlDependencies -Sql $arg) { [void]$qRefs.Add($dep) }
            }
            else {
                [void]$qRefs.Add($arg.Trim('[', ']'))
            }
        }
        $list.Add([ordered]@{
                module = $ModuleName
                name = $name
                file = $FilePath
                queryRefs = @($qRefs | Sort-Object)
                formRefs = @(Get-UniqueMatches -Text $body -Pattern '(?im)\bDoCmd\.OpenForm\s*\(\s*"([^"]+)"')
                reportRefs = @(Get-UniqueMatches -Text $body -Pattern '(?im)\bDoCmd\.OpenReport\s*\(\s*"([^"]+)"')
                callProcedures = @(Get-UniqueMatches -Text $body -Pattern '(?im)\bCall\s+([A-Za-z_][A-Za-z0-9_]*)\b')
            })
    }
    return $list.ToArray()
}

function Resolve-ProcedureMatches {
    param(
        [string]$ProcedureName,
        [string]$ObjectName,
        [ValidateSet('Form', 'Report')][string]$ObjectType,
        [hashtable]$ProcedureIndex
    )
    $key = $ProcedureName.ToLowerInvariant()
    if (-not $ProcedureIndex.ContainsKey($key)) { return @() }
    $candidates = @($ProcedureIndex[$key])
    $preferred = if ($ObjectType -eq 'Form') { @("Form_$ObjectName", $ObjectName) } else { @("Report_$ObjectName", $ObjectName) }
    $match = @($candidates | Where-Object { $preferred -contains $_.module })
    if ($match.Count -gt 0) { return $match }
    return $candidates
}

function Add-Node {
    param([hashtable]$NodeMap, [System.Collections.Generic.List[object]]$Nodes, [string]$Id, [string]$Type, [string]$Name)
    if (-not $NodeMap.ContainsKey($Id)) {
        $node = [ordered]@{ id = $Id; type = $Type; name = $Name }
        $NodeMap[$Id] = $node
        $Nodes.Add($node)
    }
}

function Add-Edge {
    param([hashtable]$EdgeMap, [System.Collections.Generic.List[object]]$Edges, [string]$From, [string]$To, [ValidateSet('usa', 'llama', 'depende_de')][string]$Type)
    $k = "$From|$Type|$To"
    if (-not $EdgeMap.ContainsKey($k)) {
        $edge = [ordered]@{ from = $From; to = $To; type = $Type }
        $EdgeMap[$k] = $edge
        $Edges.Add($edge)
    }
}

function Merge-UniqueStringArrays {
    param([object[]]$Values)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($v in $Values) {
        if ($null -eq $v) { continue }
        if ($v -is [System.Array]) {
            foreach ($x in $v) {
                if (-not [string]::IsNullOrWhiteSpace([string]$x)) { [void]$set.Add([string]$x) }
            }
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace([string]$v)) { [void]$set.Add([string]$v) }
        }
    }
    return @($set | Sort-Object)
}

Ensure-Directory -Path $OutputDir
$null = Set-Content -LiteralPath $runLogPath -Value '' -Encoding UTF8
Ensure-Directory -Path $queriesDir
Ensure-Directory -Path $formsDir
Ensure-Directory -Path $reportsDir
Ensure-Directory -Path $ribbonDir
Ensure-Directory -Path $vbaDir

Write-Log -Message "Iniciando auditoría de Access: $DatabasePath"
if (-not (Test-Path -LiteralPath $DatabasePath)) { throw "No existe la base de datos: $DatabasePath" }

$inventory = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    databasePath = $DatabasePath
    strategy = ''
    tables = @()
    queries = @()
    forms = @()
    reports = @()
    macros = @()
    modules = @()
    notes = @()
}

$tableFieldRows = New-Object System.Collections.Generic.List[object]
$relationRows = New-Object System.Collections.Generic.List[object]
$queryDependencies = [ordered]@{}
$formAnalysisRaw = New-Object System.Collections.Generic.List[object]
$reportAnalysisRaw = New-Object System.Collections.Generic.List[object]
$saveAsTextErrors = New-Object System.Collections.Generic.List[string]
$limitations = New-Object System.Collections.Generic.List[string]

$ribbonData = [ordered]@{
    source = 'none'
    ribbons = @()
    callbacks = @()
    callbackMappings = @()
    notes = @()
}

$vbaExportFiles = New-Object System.Collections.Generic.List[object]
$vbaProcedures = New-Object System.Collections.Generic.List[object]
$procedureIndex = @{}

$acForm = 2
$acReport = 3

$access = $null
$db = $null
$dbOpenedInAccess = $false
$comRouteOk = $false
$vbaTrustInstruction = 'File > Options > Trust Center > Trust Center Settings > Macro Settings > activar "Trust access to the VBA project object model".'

try {
    $access = New-Object -ComObject Access.Application
    $inventory.strategy = 'COM+DAO'
    Write-Log -Message 'Ruta preferida seleccionada: COM+DAO.'
    try { $access.Visible = $false } catch { }
    try { $access.AutomationSecurity = 3 } catch { }

    $db = $access.DBEngine.OpenDatabase($DatabasePath, $false, $true)
    Write-Log -Message 'DAO abierto en modo lectura para metadatos.'

    $tableNames = New-Object System.Collections.Generic.List[string]
    foreach ($table in $db.TableDefs) {
        $tableName = [string]$table.Name
        if ($tableName -like 'MSys*') { continue }
        $tableNames.Add($tableName)
        $indexMap = @{}
        foreach ($idx in $table.Indexes) {
            $idxLabel = if ($idx.Primary) { "$($idx.Name)[PK]" } elseif ($idx.Unique) { "$($idx.Name)[UNIQUE]" } else { [string]$idx.Name }
            foreach ($idxField in $idx.Fields) {
                $fn = [string]$idxField.Name
                if (-not $indexMap.ContainsKey($fn)) { $indexMap[$fn] = New-Object System.Collections.Generic.List[string] }
                $indexMap[$fn].Add($idxLabel)
            }
        }
        foreach ($field in $table.Fields) {
            $f = [string]$field.Name
            $size = $null
            try { $size = $field.Size } catch { }
            $required = $false
            try { $required = [bool]$field.Required } catch { }
            $defaultValue = $null
            try { $defaultValue = [string]$field.DefaultValue } catch { }
            $indexes = if ($indexMap.ContainsKey($f)) { (@($indexMap[$f] | Sort-Object -Unique) -join '; ') } else { '' }
            $tableFieldRows.Add([ordered]@{
                    Table = $tableName
                    Field = $f
                    Type = Get-DaoDataTypeName -TypeCode ([int]$field.Type)
                    Size = $size
                    Required = $required
                    DefaultValue = $defaultValue
                    Indexes = $indexes
                })
        }
    }
    $inventory.tables = @($tableNames | Sort-Object -Unique)
    Write-Log -Message ("Tablas detectadas: {0}" -f $inventory.tables.Count)

    $queryNames = New-Object System.Collections.Generic.List[string]
    foreach ($query in $db.QueryDefs) {
        $qn = [string]$query.Name
        if ([string]::IsNullOrWhiteSpace($qn) -or $qn.StartsWith('~')) { continue }
        $queryNames.Add($qn)
        $sql = [string]$query.SQL
        Set-Content -LiteralPath (Join-Path $queriesDir ((Convert-ToSafeFileName -Name $qn) + '.sql')) -Value $sql -Encoding UTF8
        $queryDependencies[$qn] = @(Parse-SqlDependencies -Sql $sql)
    }
    $inventory.queries = @($queryNames | Sort-Object -Unique)
    Write-Log -Message ("Consultas detectadas: {0}" -f $inventory.queries.Count)

    foreach ($rel in $db.Relations) {
        $rn = [string]$rel.Name
        if ([string]::IsNullOrWhiteSpace($rn) -or $rn.StartsWith('~')) { continue }
        $ri = (($rel.Attributes -band 2) -eq 0)
        foreach ($rf in $rel.Fields) {
            $src = $null
            $dst = $null
            try { $src = [string]$rf.ForeignName } catch { }
            try { $dst = [string]$rf.Name } catch { }
            $relationRows.Add([ordered]@{
                    Relation = $rn
                    TablaOrigen = [string]$rel.Table
                    TablaDestino = [string]$rel.ForeignTable
                    CampoOrigen = $src
                    CampoDestino = $dst
                    Tipo = 'PK/FK'
                    IntegridadReferencial = $ri
                })
        }
    }
    Write-Log -Message ("Relaciones detectadas: {0}" -f $relationRows.Count)

    $hasUSysRibbons = $false
    foreach ($table in $db.TableDefs) {
        if ([string]$table.Name -ieq 'USysRibbons') { $hasUSysRibbons = $true; break }
    }
    $ribbons = New-Object System.Collections.Generic.List[object]
    if ($hasUSysRibbons) {
        $ribbonData.source = 'USysRibbons'
        Write-Log -Message 'USysRibbons detectada. Extrayendo Ribbon XML.'
        $rs = $db.OpenRecordset('SELECT * FROM [USysRibbons]')
        try {
            $fields = @()
            foreach ($f in $rs.Fields) { $fields += [string]$f.Name }
            $nameField = @($fields | Where-Object { $_ -match '^(?i)RibbonName$|^Name$' } | Select-Object -First 1)
            $xmlField = @($fields | Where-Object { $_ -match '^(?i)RibbonXML$|^RibbonXml$|XML$' } | Select-Object -First 1)
            if ($nameField.Count -eq 0) { $nameField = @('RibbonName') }
            if ($xmlField.Count -eq 0) { $xmlField = @('RibbonXML') }
            $i = 0
            while (-not $rs.EOF) {
                $i++
                $rName = $null
                $rXml = $null
                try { $rName = [string]$rs.Fields[$nameField[0]].Value } catch { $rName = "Ribbon_$i" }
                try { $rXml = [string]$rs.Fields[$xmlField[0]].Value } catch { $rXml = $null }
                if ([string]::IsNullOrWhiteSpace($rName)) { $rName = "Ribbon_$i" }
                if ([string]::IsNullOrWhiteSpace($rXml)) { $rs.MoveNext(); continue }
                Set-Content -LiteralPath (Join-Path $ribbonDir ((Convert-ToSafeFileName -Name $rName) + '.xml')) -Value $rXml -Encoding UTF8
                try {
                    $ribbons.Add((Parse-RibbonXml -RibbonName $rName -XmlText $rXml))
                }
                catch {
                    $msg = "No se pudo parsear Ribbon '$rName': $($_.Exception.Message)"
                    Write-Log -Message $msg -Level 'WARN'
                    try {
                        $ribbons.Add((Parse-RibbonXmlFallback -RibbonName $rName -XmlText $rXml))
                        $limitations.Add("$msg (se aplicó fallback regex)")
                    }
                    catch {
                        $limitations.Add($msg)
                    }
                }
                $rs.MoveNext()
            }
        }
        finally {
            try { $rs.Close() } catch { }
        }
    }
    else {
        $ribbonData.source = 'DatabaseProperties'
        Write-Log -Message 'USysRibbons no existe. Buscando Ribbon en propiedades de base.'
        foreach ($pn in @('RibbonName', 'StartupRibbonName', 'AppRibbonName')) {
            try {
                $pv = [string]$db.Properties[$pn].Value
                if (-not [string]::IsNullOrWhiteSpace($pv)) { $ribbonData.notes += "Propiedad $pn = $pv" }
            }
            catch { }
        }
        if ($ribbonData.notes.Count -eq 0) { $ribbonData.notes += 'No se detectó Ribbon embebido accesible por propiedades.' }
    }
    $ribbonData.ribbons = $ribbons.ToArray()
    $ribbonData.callbacks = @($ribbons | ForEach-Object { $_.callbacks } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    $access.OpenCurrentDatabase($DatabasePath, $false)
    $dbOpenedInAccess = $true
    Write-Log -Message 'Base abierta en Access para SaveAsText y exportación VBA.'
    Write-Log -Message 'Nota: OpenCurrentDatabase no ofrece read-only; solo se ejecutan operaciones de lectura/exportación.'

    $forms = @(Get-AccessObjectNames -Collection $access.CurrentProject.AllForms)
    $reports = @(Get-AccessObjectNames -Collection $access.CurrentProject.AllReports)
    $macros = @(Get-AccessObjectNames -Collection $access.CurrentProject.AllMacros)
    $modules = @(Get-AccessObjectNames -Collection $access.CurrentProject.AllModules)

    if ($forms.Count -eq 0) {
        $forms = @(Get-DaoContainerNames -Db $db -ContainerName 'Forms')
        if ($forms.Count -gt 0) { Write-Log -Message "Forms obtenidos desde DAO.Containers: $($forms.Count)" -Level 'WARN' }
    }
    if ($reports.Count -eq 0) {
        $reports = @(Get-DaoContainerNames -Db $db -ContainerName 'Reports')
        if ($reports.Count -gt 0) { Write-Log -Message "Reports obtenidos desde DAO.Containers: $($reports.Count)" -Level 'WARN' }
    }
    if ($macros.Count -eq 0) {
        $macros = @(Get-DaoContainerNames -Db $db -ContainerName 'Scripts')
        if ($macros.Count -gt 0) { Write-Log -Message "Macros obtenidas desde DAO.Containers(Scripts): $($macros.Count)" -Level 'WARN' }
    }
    if ($modules.Count -eq 0) {
        $modules = @(Get-DaoContainerNames -Db $db -ContainerName 'Modules')
        if ($modules.Count -gt 0) { Write-Log -Message "Modules obtenidos desde DAO.Containers: $($modules.Count)" -Level 'WARN' }
    }

    $inventory.forms = $forms
    $inventory.reports = $reports
    $inventory.macros = $macros
    $inventory.modules = $modules

    $knownQueries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($q in $inventory.queries) { [void]$knownQueries.Add([string]$q) }
    $knownTables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($t in $inventory.tables) { [void]$knownTables.Add([string]$t) }

    foreach ($name in $inventory.forms) {
        $out = Join-Path $formsDir ((Convert-ToSafeFileName -Name $name) + '.txt')
        try {
            $access.SaveAsText($acForm, $name, $out)
            $meta = Parse-SaveAsTextMetadata -Text (Get-Content -LiteralPath $out -Raw -Encoding UTF8) -ObjectName $name -ObjectType Form -KnownQueries $knownQueries -KnownTables $knownTables
            $formAnalysisRaw.Add($meta)
        }
        catch {
            $msg = "SaveAsText formulario '$name' falló: $($_.Exception.Message)"
            Write-Log -Message $msg -Level 'WARN'
            $saveAsTextErrors.Add($msg)
        }
    }

    foreach ($name in $inventory.reports) {
        $out = Join-Path $reportsDir ((Convert-ToSafeFileName -Name $name) + '.txt')
        try {
            $access.SaveAsText($acReport, $name, $out)
            $meta = Parse-SaveAsTextMetadata -Text (Get-Content -LiteralPath $out -Raw -Encoding UTF8) -ObjectName $name -ObjectType Report -KnownQueries $knownQueries -KnownTables $knownTables
            $reportAnalysisRaw.Add($meta)
        }
        catch {
            $msg = "SaveAsText informe '$name' falló: $($_.Exception.Message)"
            Write-Log -Message $msg -Level 'WARN'
            $saveAsTextErrors.Add($msg)
        }
    }

    try {
        $vbProject = $access.VBE.ActiveVBProject
        foreach ($comp in $vbProject.VBComponents) {
            $cName = [string]$comp.Name
            $cType = [int]$comp.Type
            $ext = switch ($cType) {
                1 { '.bas' }
                2 { '.cls' }
                3 { '.frm' }
                100 { '.cls' }
                default { '.txt' }
            }
            $file = Join-Path $vbaDir ((Convert-ToSafeFileName -Name $cName) + $ext)
            try {
                $comp.Export($file)
                $vbaExportFiles.Add([ordered]@{ component = $cName; type = $cType; file = $file })
            }
            catch {
                $msg = "No se pudo exportar componente VBA '$cName': $($_.Exception.Message)"
                Write-Log -Message $msg -Level 'WARN'
                $limitations.Add($msg)
            }
        }
        Write-Log -Message ("Componentes VBA exportados: {0}" -f $vbaExportFiles.Count)
    }
    catch {
        $msg = "Exportación VBA no disponible. Activa: $vbaTrustInstruction"
        Write-Log -Message $msg -Level 'WARN'
        $limitations.Add($msg)
    }

    $comRouteOk = $true
}
catch {
    $msg = "Ruta COM+DAO falló: $($_.Exception.Message)"
    Write-Log -Message $msg -Level 'ERROR'
    $limitations.Add($msg)
}
finally {
    if ($null -ne $db) {
        try { $db.Close() } catch { }
        try { [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($db) } catch { }
    }
    if ($null -ne $access) {
        if ($dbOpenedInAccess) { try { $access.CloseCurrentDatabase() } catch { } }
        try { $access.Quit() } catch { }
        try { [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($access) } catch { }
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

if (-not $comRouteOk) {
    Write-Log -Message 'Activando ruta alterna ODBC.' -Level 'WARN'
    $inventory.strategy = 'ODBC'
    $limitations.Add('ODBC no permite exportar Ribbon/SaveAsText/VBA.')
    $conn = $null
    try {
        $conn = New-Object System.Data.Odbc.OdbcConnection("Driver={Microsoft Access Driver (*.mdb, *.accdb)};Dbq=$DatabasePath;")
        $conn.Open()
        $tableNames = New-Object System.Collections.Generic.List[string]
        foreach ($row in $conn.GetSchema('Tables').Rows) {
            $tType = [string]$row['TABLE_TYPE']
            $tName = [string]$row['TABLE_NAME']
            if (($tType -eq 'TABLE' -or $tType -eq 'VIEW') -and -not ($tName -like 'MSys*')) { $tableNames.Add($tName) }
        }
        $inventory.tables = @($tableNames | Sort-Object -Unique)
        foreach ($row in $conn.GetSchema('Columns').Rows) {
            $tn = [string]$row['TABLE_NAME']
            if ($tn -like 'MSys*') { continue }
            $tableFieldRows.Add([ordered]@{
                    Table = $tn
                    Field = [string]$row['COLUMN_NAME']
                    Type = [string]$row['TYPE_NAME']
                    Size = [string]$row['COLUMN_SIZE']
                    Required = ([string]$row['IS_NULLABLE'] -eq 'NO')
                    DefaultValue = [string]$row['COLUMN_DEF']
                    Indexes = ''
                })
        }
        try {
            foreach ($row in $conn.GetSchema('ForeignKeys').Rows) {
                $relationRows.Add([ordered]@{
                        Relation = [string]$row['FK_NAME']
                        TablaOrigen = [string]$row['PK_TABLE_NAME']
                        TablaDestino = [string]$row['FK_TABLE_NAME']
                        CampoOrigen = [string]$row['PK_COLUMN_NAME']
                        CampoDestino = [string]$row['FK_COLUMN_NAME']
                        Tipo = 'PK/FK'
                        IntegridadReferencial = $true
                    })
            }
        }
        catch {
            $limitations.Add('ODBC: no fue posible leer ForeignKeys schema.')
        }
    }
    catch {
        $msg = "Falla ruta ODBC: $($_.Exception.Message)"
        Write-Log -Message $msg -Level 'ERROR'
        $limitations.Add($msg)
    }
    finally {
        if ($null -ne $conn) { try { $conn.Close() } catch { }; $conn.Dispose() }
    }
}

foreach ($file in Get-ChildItem -LiteralPath $vbaDir -File -ErrorAction SilentlyContinue) {
    if ($file.Extension -notin @('.bas', '.cls', '.frm')) { continue }
    $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    try {
        foreach ($p in Parse-VbaProceduresFromFile -FilePath $file.FullName -ModuleName $moduleName) {
            $vbaProcedures.Add($p)
            $k = $p.name.ToLowerInvariant()
            if (-not $procedureIndex.ContainsKey($k)) { $procedureIndex[$k] = New-Object System.Collections.Generic.List[object] }
            $procedureIndex[$k].Add($p)
        }
    }
    catch {
        $limitations.Add("No se pudo parsear VBA '$($file.FullName)': $($_.Exception.Message)")
    }
}

$inventory.modules = @(Merge-UniqueStringArrays -Values @($inventory.modules, @($vbaExportFiles | ForEach-Object { $_.component })))

$formAnalysis = New-Object System.Collections.Generic.List[object]
foreach ($m in $formAnalysisRaw) {
    $resolved = New-Object System.Collections.Generic.List[object]
    $unresolved = New-Object System.Collections.Generic.List[string]
    foreach ($hint in $m.procedureHints) {
        $matches = Resolve-ProcedureMatches -ProcedureName $hint -ObjectName $m.name -ObjectType Form -ProcedureIndex $procedureIndex
        if ($matches.Count -eq 0) { $unresolved.Add($hint) } else {
            foreach ($x in $matches) { $resolved.Add([ordered]@{ procedure = $x.name; module = $x.module }) }
        }
    }
    $clicks = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $mods = @("Form_$($m.name)", [string]$m.name)
    foreach ($p in $vbaProcedures) {
        if ($mods -contains [string]$p.module -and [string]$p.name -like '*_Click') { [void]$clicks.Add([string]$p.name) }
    }
    $formAnalysis.Add([ordered]@{
            name = $m.name
            objectType = 'Form'
            recordSource = $m.recordSource
            rowSources = $m.rowSources
            events = $m.events
            queryOrTableRefs = $m.queryOrTableRefs
            procedureHints = $m.procedureHints
            resolvedProcedures = @($resolved | Sort-Object module, procedure -Unique)
            unresolvedProcedureHints = @($unresolved | Sort-Object -Unique)
            clickProceduresDetected = @($clicks | Sort-Object)
        })
}

$reportAnalysis = New-Object System.Collections.Generic.List[object]
foreach ($m in $reportAnalysisRaw) {
    $resolved = New-Object System.Collections.Generic.List[object]
    $unresolved = New-Object System.Collections.Generic.List[string]
    foreach ($hint in $m.procedureHints) {
        $matches = Resolve-ProcedureMatches -ProcedureName $hint -ObjectName $m.name -ObjectType Report -ProcedureIndex $procedureIndex
        if ($matches.Count -eq 0) { $unresolved.Add($hint) } else {
            foreach ($x in $matches) { $resolved.Add([ordered]@{ procedure = $x.name; module = $x.module }) }
        }
    }
    $reportAnalysis.Add([ordered]@{
            name = $m.name
            objectType = 'Report'
            recordSource = $m.recordSource
            rowSources = $m.rowSources
            events = $m.events
            queryOrTableRefs = $m.queryOrTableRefs
            procedureHints = $m.procedureHints
            resolvedProcedures = @($resolved | Sort-Object module, procedure -Unique)
            unresolvedProcedureHints = @($unresolved | Sort-Object -Unique)
        })
}

$callbackMappings = New-Object System.Collections.Generic.List[object]
foreach ($r in $ribbonData.ribbons) {
    foreach ($c in $r.controls) {
        if ([string]::IsNullOrWhiteSpace([string]$c.onAction)) { continue }
        $cb = Normalize-CallbackName -Value ([string]$c.onAction)
        if ([string]::IsNullOrWhiteSpace($cb)) {
            $callbackMappings.Add([ordered]@{
                    Ribbon = $r.ribbonName
                    ControlType = $c.type
                    ControlId = if ($c.id) { $c.id } else { $c.idMso }
                    Label = $c.label
                    onAction = $c.onAction
                    Callback = $null
                    ProcedureFound = $false
                    Module = $null
                    Procedure = $null
                })
            continue
        }
        $k = $cb.ToLowerInvariant()
        if ($procedureIndex.ContainsKey($k)) {
            foreach ($p in $procedureIndex[$k]) {
                $callbackMappings.Add([ordered]@{
                        Ribbon = $r.ribbonName
                        ControlType = $c.type
                        ControlId = if ($c.id) { $c.id } else { $c.idMso }
                        Label = $c.label
                        onAction = $c.onAction
                        Callback = $cb
                        ProcedureFound = $true
                        Module = $p.module
                        Procedure = $p.name
                    })
            }
        }
        else {
            $callbackMappings.Add([ordered]@{
                    Ribbon = $r.ribbonName
                    ControlType = $c.type
                    ControlId = if ($c.id) { $c.id } else { $c.idMso }
                    Label = $c.label
                    onAction = $c.onAction
                    Callback = $cb
                    ProcedureFound = $false
                    Module = $null
                    Procedure = $null
                })
        }
    }
}
$ribbonData.callbackMappings = $callbackMappings.ToArray()

$knownTables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($t in $inventory.tables) { [void]$knownTables.Add([string]$t) }
$knownQueries = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($q in $inventory.queries) { [void]$knownQueries.Add([string]$q) }
$knownForms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $inventory.forms) { [void]$knownForms.Add([string]$f) }
$knownReports = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($r in $inventory.reports) { [void]$knownReports.Add([string]$r) }

$nodes = New-Object System.Collections.Generic.List[object]
$edges = New-Object System.Collections.Generic.List[object]
$nodeMap = @{}
$edgeMap = @{}

foreach ($t in $inventory.tables) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "table:$t" -Type 'Table' -Name $t }
foreach ($q in $inventory.queries) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "query:$q" -Type 'Query' -Name $q }
foreach ($f in $inventory.forms) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "form:$f" -Type 'Form' -Name $f }
foreach ($r in $inventory.reports) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "report:$r" -Type 'Report' -Name $r }
foreach ($p in $vbaProcedures) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "proc:$($p.module).$($p.name)" -Type 'Procedure' -Name "$($p.module).$($p.name)" }
foreach ($r in $ribbonData.ribbons) { Add-Node -NodeMap $nodeMap -Nodes $nodes -Id "ribbon:$($r.ribbonName)" -Type 'Ribbon' -Name $r.ribbonName }

foreach ($qName in $queryDependencies.Keys) {
    foreach ($dep in $queryDependencies[$qName]) {
        $from = "query:$qName"
        if ($knownQueries.Contains($dep)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "query:$dep" -Type 'depende_de'; continue }
        if ($knownTables.Contains($dep)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "table:$dep" -Type 'depende_de'; continue }
        $u = "unknown:$dep"
        Add-Node -NodeMap $nodeMap -Nodes $nodes -Id $u -Type 'Unknown' -Name $dep
        Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To $u -Type 'depende_de'
    }
}
foreach ($m in $formAnalysis) {
    $from = "form:$($m.name)"
    foreach ($ref in $m.queryOrTableRefs) {
        if ($knownQueries.Contains($ref)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "query:$ref" -Type 'usa' }
        elseif ($knownTables.Contains($ref)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "table:$ref" -Type 'usa' }
    }
    foreach ($rp in $m.resolvedProcedures) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "proc:$($rp.module).$($rp.procedure)" -Type 'llama' }
}
foreach ($m in $reportAnalysis) {
    $from = "report:$($m.name)"
    foreach ($ref in $m.queryOrTableRefs) {
        if ($knownQueries.Contains($ref)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "query:$ref" -Type 'usa' }
        elseif ($knownTables.Contains($ref)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "table:$ref" -Type 'usa' }
    }
    foreach ($rp in $m.resolvedProcedures) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "proc:$($rp.module).$($rp.procedure)" -Type 'llama' }
}
foreach ($p in $vbaProcedures) {
    $from = "proc:$($p.module).$($p.name)"
    foreach ($qr in $p.queryRefs) {
        if ($knownQueries.Contains($qr)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "query:$qr" -Type 'usa' }
        elseif ($knownTables.Contains($qr)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "table:$qr" -Type 'usa' }
    }
    foreach ($fr in $p.formRefs) { if ($knownForms.Contains($fr)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "form:$fr" -Type 'usa' } }
    foreach ($rr in $p.reportRefs) { if ($knownReports.Contains($rr)) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "report:$rr" -Type 'usa' } }
    foreach ($cp in $p.callProcedures) {
        $k = $cp.ToLowerInvariant()
        if ($procedureIndex.ContainsKey($k)) {
            foreach ($dst in $procedureIndex[$k]) { Add-Edge -EdgeMap $edgeMap -Edges $edges -From $from -To "proc:$($dst.module).$($dst.name)" -Type 'llama' }
        }
    }
}
foreach ($m in $callbackMappings) {
    if (-not $m.ProcedureFound) { continue }
    Add-Edge -EdgeMap $edgeMap -Edges $edges -From "ribbon:$($m.Ribbon)" -To "proc:$($m.Module).$($m.Procedure)" -Type 'llama'
}

$inventory.notes = @(Merge-UniqueStringArrays -Values @($limitations, $saveAsTextErrors, $ribbonData.notes))

$inventoryPath = Join-Path $OutputDir 'inventory.json'
$tablesFieldsPath = Join-Path $OutputDir 'tables_fields.csv'
$relationsPath = Join-Path $OutputDir 'relations.csv'
$queryDepsPath = Join-Path $queriesDir 'query_dependencies.json'
$formsAnalysisPath = Join-Path $formsDir 'forms_analysis.json'
$reportsAnalysisPath = Join-Path $reportsDir 'reports_analysis.json'
$ribbonAnalysisPath = Join-Path $ribbonDir 'ribbon_analysis.json'
$ribbonMapPath = Join-Path $ribbonDir 'ribbon_callback_map.csv'
$dependencyPath = Join-Path $OutputDir 'dependency_graph.json'
$summaryPath = Join-Path $OutputDir 'summary.md'

$tableFieldRows | Sort-Object Table, Field | Export-Csv -LiteralPath $tablesFieldsPath -NoTypeInformation -Encoding UTF8
$relationRows | Sort-Object Relation, TablaOrigen, CampoOrigen | Export-Csv -LiteralPath $relationsPath -NoTypeInformation -Encoding UTF8
Save-JsonFile -Data $inventory -Path $inventoryPath
Save-JsonFile -Data $queryDependencies -Path $queryDepsPath
Save-JsonFile -Data $formAnalysis -Path $formsAnalysisPath
Save-JsonFile -Data $reportAnalysis -Path $reportsAnalysisPath
Save-JsonFile -Data $ribbonData -Path $ribbonAnalysisPath
if ($callbackMappings.Count -gt 0) {
    @($callbackMappings | Where-Object { $null -ne $_ } | ForEach-Object { [pscustomobject]$_ }) | Export-Csv -LiteralPath $ribbonMapPath -NoTypeInformation -Encoding UTF8
}
else {
    Set-Content -LiteralPath $ribbonMapPath -Value 'Ribbon,ControlType,ControlId,Label,onAction,Callback,ProcedureFound,Module,Procedure' -Encoding UTF8
}
Save-JsonFile -Data ([ordered]@{
        generatedAt = (Get-Date).ToString('o')
        databasePath = $DatabasePath
        strategy = $inventory.strategy
        nodes = $nodes.ToArray()
        edges = $edges.ToArray()
        stats = [ordered]@{ nodes = $nodes.Count; edges = $edges.Count }
    }) -Path $dependencyPath

$incoming = @{}
foreach ($e in $edges) {
    if (-not $incoming.ContainsKey($e.to)) { $incoming[$e.to] = 0 }
    $incoming[$e.to]++
}

$topForms = @($inventory.forms | ForEach-Object {
        $id = "form:$_"
        $score = if ($incoming.ContainsKey($id)) { $incoming[$id] } else { 0 }
        [ordered]@{ name = $_; score = $score }
    } | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'name'; Descending = $false } | Select-Object -First 10)

$topQueries = @($inventory.queries | ForEach-Object {
        $id = "query:$_"
        $in = if ($incoming.ContainsKey($id)) { $incoming[$id] } else { 0 }
        $dep = if ($queryDependencies.Contains($_)) { @($queryDependencies[$_]).Count } else { 0 }
        [ordered]@{ name = $_; score = ($in + $dep); incoming = $in; deps = $dep }
    } | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'name'; Descending = $false } | Select-Object -First 10)

$topTables = @($inventory.tables | ForEach-Object {
        $id = "table:$_"
        $score = if ($incoming.ContainsKey($id)) { $incoming[$id] } else { 0 }
        [ordered]@{ name = $_; score = $score }
    } | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'name'; Descending = $false } | Select-Object -First 10)

$moduleScores = @{}
foreach ($p in $vbaProcedures) {
    $id = "proc:$($p.module).$($p.name)"
    $score = if ($incoming.ContainsKey($id)) { $incoming[$id] } else { 0 }
    if (-not $moduleScores.ContainsKey($p.module)) { $moduleScores[$p.module] = 0 }
    $moduleScores[$p.module] += $score
}
$topModules = @($moduleScores.GetEnumerator() | ForEach-Object { [ordered]@{ module = $_.Key; score = $_.Value } } | Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = 'module'; Descending = $false } | Select-Object -First 10)

$unresolvedCallbackSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($m in $callbackMappings) {
    $found = $false
    $cb = $null
    if ($m -is [System.Collections.IDictionary]) {
        $found = [bool]$m['ProcedureFound']
        $cb = [string]$m['Callback']
    }
    else {
        try { $found = [bool]$m.ProcedureFound } catch { $found = $false }
        try { $cb = [string]$m.Callback } catch { $cb = $null }
    }
    if (-not $found -and -not [string]::IsNullOrWhiteSpace($cb)) {
        [void]$unresolvedCallbackSet.Add($cb)
    }
}
$unresolvedCallbacks = @($unresolvedCallbackSet | Sort-Object)

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add('# Auditoría estructural DAT_PV.accdb')
$summary.Add('')
$summary.Add("Fecha: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
$summary.Add("Base: $DatabasePath")
$summary.Add("Estrategia aplicada: $($inventory.strategy)")
$summary.Add("Salida: $OutputDir")
$summary.Add('')
$summary.Add('## Conteos')
$summary.Add("- Tablas: $($inventory.tables.Count)")
$summary.Add("- Consultas: $($inventory.queries.Count)")
$summary.Add("- Formularios: $($inventory.forms.Count)")
$summary.Add("- Informes: $($inventory.reports.Count)")
$summary.Add("- Macros: $($inventory.macros.Count)")
$summary.Add("- Módulos: $($inventory.modules.Count)")
$summary.Add("- Callbacks Ribbon detectados: $(@($ribbonData.callbacks).Count)")
$summary.Add('')
$summary.Add('## Flujo principal inferido')
if ($ribbonData.ribbons.Count -gt 0) {
    $summary.Add("1. Inicio por Ribbon(s): $((@($ribbonData.ribbons | ForEach-Object { $_.ribbonName }) -join ', ')).")
    $summary.Add('2. Controles Ribbon ejecutan callbacks onAction hacia procedimientos VBA.')
    $summary.Add('3. Procedimientos llaman formularios, consultas y tablas núcleo.')
}
else {
    $summary.Add('1. Sin USysRibbons parseable; flujo inferido desde formularios/reportes y VBA.')
}
$summary.Add('')
$summary.Add('## Formularios centrales')
if ($topForms.Count -eq 0) { $summary.Add('- No se identificaron formularios.') } else { foreach ($x in $topForms) { $summary.Add("- $($x.name) (referencias entrantes: $($x.score))") } }
$summary.Add('')
$summary.Add('## Consultas críticas')
if ($topQueries.Count -eq 0) { $summary.Add('- No se identificaron consultas.') } else { foreach ($x in $topQueries) { $summary.Add("- $($x.name) (peso: $($x.score), uso: $($x.incoming), dependencias: $($x.deps))") } }
$summary.Add('')
$summary.Add('## Tablas núcleo')
if ($topTables.Count -eq 0) { $summary.Add('- No se identificaron tablas.') } else { foreach ($x in $topTables) { $summary.Add("- $($x.name) (referencias: $($x.score))") } }
$summary.Add('')
$summary.Add('## Módulos más referenciados')
if ($topModules.Count -eq 0) { $summary.Add('- No se identificaron módulos/procedimientos exportados.') } else { foreach ($x in $topModules) { $summary.Add("- $($x.module) (score: $($x.score))") } }
$summary.Add('')
$summary.Add('## Posibles puntos frágiles')
if ($unresolvedCallbacks.Count -gt 0) { $summary.Add("- Callbacks Ribbon sin resolver: $($unresolvedCallbacks -join ', ')") }
if ($saveAsTextErrors.Count -gt 0) { $summary.Add("- Objetos con falla SaveAsText: $($saveAsTextErrors.Count)") }
if ($limitations.Count -gt 0) { foreach ($x in $limitations) { $summary.Add("- $x") } }
if ($unresolvedCallbacks.Count -eq 0 -and $saveAsTextErrors.Count -eq 0 -and $limitations.Count -eq 0) { $summary.Add('- Sin fallas críticas durante la extracción.') }

Set-Content -LiteralPath $summaryPath -Value ($summary -join [Environment]::NewLine) -Encoding UTF8

Write-Log -Message 'Artefactos generados.'
Write-Log -Message " - $inventoryPath"
Write-Log -Message " - $tablesFieldsPath"
Write-Log -Message " - $relationsPath"
Write-Log -Message " - $queryDepsPath"
Write-Log -Message " - $formsAnalysisPath"
Write-Log -Message " - $reportsAnalysisPath"
Write-Log -Message " - $ribbonAnalysisPath"
Write-Log -Message " - $ribbonMapPath"
Write-Log -Message " - $dependencyPath"
Write-Log -Message " - $summaryPath"

Write-Host ''
Write-Host '================ summary.md ================'
Get-Content -LiteralPath $summaryPath
Write-Host '==========================================='
Write-Host ("Conteos finales -> Tablas: {0}; Consultas: {1}; Formularios: {2}; Módulos: {3}; Callbacks Ribbon: {4}" -f $inventory.tables.Count, $inventory.queries.Count, $inventory.forms.Count, $inventory.modules.Count, @($ribbonData.callbacks).Count)
