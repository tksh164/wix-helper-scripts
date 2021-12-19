param(
    # ex. 'J:\src\app\bin\Release\net6.0-windows\publish\win-x86'
    [Parameter(Mandatory = $true)]
    [string] $SourceFolderPath,

    # ex. 'J:\src\app\bin\Release\net6.0-windows\'
    [Parameter(Mandatory = $true)]
    [string] $ReplacedPartInSourceFolderPath,

    # ex. $(var.app.TargetDir)
    [Parameter(Mandatory = $true)]
    [string] $ReplaceString
)

function New-ElementId
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prefix
    )
    $Prefix + '_' + (New-Guid).Guid.ToString().Replace('-', '').ToLowerInvariant()
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

class FragmentElement : BaseElement
{
    [BaseElement[]] $Children

    FragmentElement()
    {}

    [string] ToXmlString()
    {
        $builder = [System.Text.StringBuilder]::new()
        $builder.AppendLine('<Fragment>')
        foreach ($c in $this.Children) {
            $builder.AppendLine($c.ToXmlString())
        }
        $builder.Append('</Fragment>')
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

class ComponentElement : BaseElement
{
    [BaseElement[]] $Children

    ComponentElement()
    {
        $this.Id = New-ElementId -Prefix 'comp'
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
        return '<File Id="{0}" Source="{1}" KeyPath="yes" ReadOnly="yes"/>' -f $this.Id, $this.Source
    }
}

class ComponentGroupElement : BaseElement
{
    [BaseElement[]] $Children

    ComponentGroupElement([string] $Id)
    {
        $this.Id = $Id
    }

    [string] ToXmlString()
    {
        $builder = [System.Text.StringBuilder]::new()
        $builder.AppendLine('<ComponentGroup Id="{0}">' -f $this.Id)
        foreach ($c in $this.Children) {
            $builder.AppendLine($c.ToXmlString())
        }
        $builder.Append('</ComponentGroup>')
        return $builder.ToString()
    }
}

class ComponentRefElement : BaseElement
{
    ComponentRefElement([string] $Id)
    {
        $this.Id = $Id
    }

    [string] ToXmlString()
    {
        return '<ComponentRef Id="{0}"/>' -f $this.Id
    }
}

function New-DirectoryRefFragment
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $SourceFolderPath,

        [Parameter(Mandatory = $true)]
        [string] $ReplacedPartInSourceFolderPath,

        [Parameter(Mandatory = $true)]
        [string] $ReplaceString,

        [Parameter(Mandatory = $true)]
        [string] $DirectoryRefElementId
    )

    $dirRefElm = [DirectoryRefElement]::new($DirectoryRefElementId)

    Add-ChildElement -ParentElememnt $dirRefElm -SourceFolderPath $SourceFolderPath -ReplacedPartInSourceFolderPath $ReplacedPartInSourceFolderPath -ReplaceString $ReplaceString

    $fragmentElm = [FragmentElement]::new()
    $fragmentElm.Children += $dirRefElm
    $fragmentElm
}

function Add-ChildElement
{
    param(
        [Parameter(Mandatory = $true)]
        [BaseElement] $ParentElememnt,

        [Parameter(Mandatory = $true)]
        [string] $SourceFolderPath,

        [Parameter(Mandatory = $true)]
        [string] $ReplacedPartInSourceFolderPath,

        [Parameter(Mandatory = $true)]
        [string] $ReplaceString
    )

    # Files
    Get-ChildItem -File -LiteralPath $SourceFolderPath |
        ForEach-Object -Process {
            $fileSource = $_.FullName.Replace($ReplacedPartInSourceFolderPath, $ReplaceString)
            $componentElm = [ComponentElement]::new()
            $componentElm.Children += [FileElement]::new($fileSource)
            $ParentElememnt.Children += $componentElm
        }

    # Folders
    Get-ChildItem -Directory -LiteralPath $SourceFolderPath |
        ForEach-Object -Process {
            $directoryName = [System.IO.Path]::GetFileName($_.FullName)
            $dirElm = [DirectoryElement]::new($directoryName)
            $ParentElememnt.Children += $dirElm
            Add-ChildElement -ParentElememnt $dirElm -SourceFolderPath $_.FullName -ReplacedPartInSourceFolderPath $ReplacedPartInSourceFolderPath -ReplaceString $ReplaceString
        }
}

function New-ComponentGroupFragment
{
    param(
        [Parameter(Mandatory = $true)]
        [BaseElement] $RootElement,

        [Parameter(Mandatory = $true)]
        [string] $ComponentGroupElementId
    )

    $compGroupElm = [ComponentGroupElement]::new($ComponentGroupElementId)
   
    Get-ChildComponentElement -RootElement $RootElement |
        ForEach-Object -Process {
            $compGroupElm.Children += [ComponentRefElement]::new($_.Id)
        }

    $fragmentElm = [FragmentElement]::new()
    $fragmentElm.Children += $compGroupElm
    $fragmentElm
}

function Get-ChildComponentElement
{
    param(
        [Parameter(Mandatory = $true)]
        [BaseElement] $RootElement
    )

    foreach ($elm in $RootElement.Children) {
        if ($elm -is [ComponentElement]) {
            $elm
        }
        elseif ($elm -is [DirectoryElement]) {
            Get-ChildComponentElement -RootElement $elm
        }
        elseif ($elm -is [DirectoryRefElement]) {
            Get-ChildComponentElement -RootElement $elm
        }
    }
}

$drf = New-DirectoryRefFragment -SourceFolderPath $SourceFolderPath -ReplacedPartInSourceFolderPath $ReplacedPartInSourceFolderPath -ReplaceString $ReplaceString -DirectoryRefElementId 'INSTALLFOLDER'
$drf.ToXmlString()

$cgf = New-ComponentGroupFragment -RootElement $drf -ComponentGroupElementId 'ProductComponents'
$cgf.ToXmlString()
