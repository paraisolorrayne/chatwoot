# Conversas e central de suporte

A central fica em `/app/accounts/:accountId/synapseos/support`, acessível pelo menu
para administradores e atendentes. O pedido sai pelo WhatsApp selecionado da conta,
identificado com o nome e e-mail do usuário autenticado, conta, assunto, descrição
e protocolo. O destinatário padrão é `+5511991847629`.

## Envio e permissões

- Cada usuário só vê e utiliza os canais WhatsApp aos quais tem acesso na conta atual.
- O destinatário é definido no servidor; o cliente não pode substituir o número.
- O envio utiliza `Message` e `SendReplyJob`, os mesmos componentes das conversas.
  Sidekiq e o canal precisam estar operacionais.
- Um UUID por pedido evita duplicação quando o navegador repete a requisição após timeout.
- O histórico mostra os últimos 50 pedidos dos canais acessíveis, atualiza a cada 10 segundos
  e permite abrir a conversa. `queued` significa envio ainda sem confirmação do provedor;
  `sent`, `delivered`, `read` e `failed` acompanham o estado da mensagem.
- Em falha, abra a conversa pelo assunto do pedido para consultar o erro e tentar novamente.

## Configuração

| Variável | Padrão | Uso |
| --- | --- | --- |
| `SYNAPSEOS_SUPPORT_PHONE` | `+5511991847629` | Destinatário em E.164 |
| `SYNAPSEOS_SUPPORT_TEMPLATE_NAME` | não definido | Template de suporte aprovado para iniciar conversa pela API oficial |
| `SYNAPSEOS_SUPPORT_TEMPLATE_LANGUAGE` | `pt_BR` | Idioma do template aprovado |
| `CONVERSATION_RESULTS_PER_PAGE` | `100` | Conversas por lote, limitado entre 1 e 200 |

Avisa e Hyperflow usam o envio de texto já disponível no fork. Canais oficiais
usam texto dentro da janela de resposta. Fora dela, é necessário configurar um
**template aprovado com um único parâmetro posicional de corpo `{{1}}`**, sem
cabeçalho ou botões que exijam parâmetros. Esse parâmetro recebe os dados do pedido.
Sem template aprovado, a API retorna `422` com `window_closed`, o formulário mantém
os dados e orienta o operador. Nenhuma mensagem é criada nesse caso.

Os textos do suporte e da paginação estão disponíveis em português brasileiro e inglês.
A central usa o mesmo cliente autenticado das demais APIs do painel; importar o Axios
sem essa configuração deixa as chamadas sem os headers de sessão e provoca erro 401.

## Conversas

A listagem normal e os filtros avançados usam o mesmo tamanho de lote. O histórico
carrega 100 mensagens por vez (antes 20). A lista antecipa a próxima página 600 px
antes do fim, mantém a virtualização e oferece carregamento manual e recuperação
quando a API falha. Não há um teto de quantidade total de conversas navegáveis.
Chegar ao final de “Todas” não encerra a paginação de “Minhas”.

A interface mantém os tokens da marca e moderniza o espaçamento da navegação,
cabeçalhos, cartões de conversa, estado selecionado e editor de mensagens.

## Verificação de produto

1. Abra uma conta com mais de 100 conversas e role além do primeiro lote.
2. Alcance o final de “Todas”, troque para “Minhas” e confira o carregamento.
3. Use filtros avançados e abra uma conversa com mais de 100 mensagens.
4. Interrompa uma chamada de listagem e use o botão de tentar carregar novamente.
5. Abra Suporte; selecione um canal autorizado e preencha assunto e descrição.
6. Envie em ambiente de homologação e acompanhe fila, envio e entrega no histórico.
7. Confira a mensagem no destinatário e a identificação do solicitante.
8. Confira mobile e tema escuro.

As verificações locais usam dados fictícios e bloqueiam chamadas externas.
A entrega real por cada provedor deve ser conferida em homologação com o canal configurado.
Não há nova migração de banco de dados nesta alteração.

## Testes automatizados

- `spec/services/synapseos/support_request_service_spec.rb` — conteúdo e destinatário
  da mensagem, idempotência por protocolo, reuso da conversa de suporte, validação de
  entrada, janela fechada sem template (nada é criado), template aprovado com o pedido
  no parâmetro `{{1}}` e envio de sessão dentro da janela.
- `spec/controllers/api/v1/accounts/synapseos/support_requests_spec.rb` — autenticação,
  isolamento entre contas, canais visíveis por usuário, `queued`/`failed` no histórico,
  `422` com `invalid_request` e `window_closed`, inbox inacessível ou de outra conta (`404`).

```bash
RAILS_ENV=test bundle exec rspec spec/services/synapseos/support_request_service_spec.rb \
  spec/controllers/api/v1/accounts/synapseos/support_requests_spec.rb \
  spec/finders/conversation_finder_spec.rb spec/finders/message_finder_spec.rb \
  spec/services/conversations/filter_service_spec.rb
```
