@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Scripts interativos de bootstrap: a saida colorida no console e intencional.
        'PSAvoidUsingWriteHost',
        # Funcoes internas e idempotentes do bootstrap; -WhatIf nao faz parte do contrato.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}
