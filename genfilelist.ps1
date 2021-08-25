function New-ElementId
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prefix
    )
    $Prefix + (New-Guid).Guid.ToString().Replace('-', '').ToUpperInvariant()
}

class BaseElement
{
    [string] $Id

    BaseElement()
    {}

    [string] ToXmlString()
    {
        return '**BaseElement**'
    }
}

class FileElement : BaseElement
{
    [string] $Source

    FileElement([string] $Source)
    {
        $this.Id = New-ElementId -Prefix 'file'
        $this.Source = $Source
    }

    [string] ToXmlString()
    {
        return '<File Id="{0}" KeyPath="yes" ReadOnly="yes" Source="{1}"/>' -f $this.Id, $this.Source
    }
}

class ComponentElement : BaseElement
{
    [BaseElement[]] $Children

    ComponentElement()
    {
        $this.Id = New-ElementId -Prefix 'cmp'
    }

    [string] ToXmlString()
    {
        $builder = [System.Text.StringBuilder]::new()
        $builder.AppendLine('<Component Id="{0}">' -f $this.Id)
        foreach ($c in $this.Children) {
            $builder.AppendLine($c.ToXmlString())
        }
        $builder.Append('</Component>')
        return $builder.ToString()
    }
}

class DirectoryElement : BaseElement
{
    [string] $Name
    [BaseElement[]] $Children

    DirectoryElement([string] $Name)
    {
        $this.Id = New-ElementId -Prefix 'dir'
        $this.Name = $Name
    }

    [string] ToXmlString()
    {
        $builder = [System.Text.StringBuilder]::new()
        $builder.AppendLine(('<Directory Id="{0}" Name="{1}">' -f $this.Id, $this.Name))
        foreach ($c in $this.Children) {
            $builder.AppendLine($c.ToXmlString())
        }
        $builder.Append('</Directory>')
        return $builder.ToString()
    }
}

class DirectoryRefElement : BaseElement
{
    [BaseElement[]] $Children

    DirectoryRefElement([string] $Id)
    {
        $this.Id = $Id
    }

    [string] ToXmlString()
    {
        $builder = [System.Text.StringBuilder]::new()
        $builder.AppendLine('<DirectoryRef Id="{0}">' -f $this.Id)
        foreach ($c in $this.Children) {
            $builder.AppendLine($c.ToXmlString())
        }
        $builder.Append('</DirectoryRef>')
        return $builder.ToString()
    }
}

function Build-DirectoryStructure
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $BaseDirectoryPath,

        [Parameter(Mandatory = $true)]
        [BaseElement] $ParentElememnt,

        [Parameter(Mandatory = $true)]
        [string] $PartOfPathToBeReplaced,

        [Parameter(Mandatory = $true)]
        [string] $ReplaceString
    )

    Get-ChildItem -File -LiteralPath $BaseDirectoryPath |
        ForEach-Object -Process {
            $fileSource = $_.FullName.Replace($PartOfPathToBeReplaced, $ReplaceString)
            $fileElm = [FileElement]::new($fileSource)
            $componentElm = [ComponentElement]::new()
            $componentElm.Children += $fileElm
            $ParentElememnt.Children += $componentElm
        }

    Get-ChildItem -Directory -LiteralPath $BaseDirectoryPath |
        ForEach-Object -Process {
            $directoryName = [System.IO.Path]::GetFileName($_.FullName)
            $dirElm = [DirectoryElement]::new($directoryName)
            $ParentElememnt.Children += $dirElm
            Build-DirectoryStructure -BaseDirectoryPath $_.FullName -ParentElememnt $dirElm -PartOfPathToBeReplaced $PartOfPathToBeReplaced -ReplaceString $ReplaceString
        }
}


$baseFolderPath = ''
$partOfPathToBeReplaced = ''
$replaceString = '$(var.DemoApp.TargetDir)'

$dirRefElm = [DirectoryRefElement]::new('INSTALLFOLDER')
Build-DirectoryStructure -BaseDirectoryPath $baseFolderPath -ParentElememnt $dirRefElm -PartOfPathToBeReplaced $partOfPathToBeReplaced -ReplaceString $replaceString
$dirRefElm.ToXmlString() | clip


# TODO: Generate ComponentGroup XML fragment.
