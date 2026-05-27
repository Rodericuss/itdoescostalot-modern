# Design System — Paleta de Cores
**Projeto:** Sistema de controle financeiro (fintech)
**Contexto:** Light mode · Público fintech/mercado · Vibe moderno e tech

---

## Cores base

| Nome | Hex | Uso |
|---|---|---|
| MIT Red | `#A31F34` | Cor primária / brand |
| Deep Red | `#7A1626` | Hover e active states do primário |
| Ice White | `#F8F7F5` | Background principal da página |
| Pure White | `#FFFFFF` | Superfície de cards e modais |

---

## Neutros

| Nome | Hex | Uso |
|---|---|---|
| Ink | `#1A1A1A` | Texto primário |
| Slate | `#5F5E5A` | Texto secundário / labels |
| Mist | `#E0DEDB` | Bordas e divisores |

---

## Cores semânticas (feedback financeiro)

| Nome | Hex | Significado |
|---|---|---|
| Profit Green | `#1D9E75` | Ganho, entrada, saldo positivo, meta atingida |
| Loss Red | `#E24B4A` | Perda, saída, saldo negativo, erro |
| Warning Amber | `#BA7517` | Alerta, atenção, prazo próximo |
| Info Blue | `#185FA5` | Informação, links, tooltips neutros |

---

## Variáveis CSS (para uso no código)

```css
:root {
  /* Base */
  --color-brand:        #A31F34;
  --color-brand-hover:  #7A1626;
  --color-bg-page:      #F8F7F5;
  --color-bg-surface:   #FFFFFF;

  /* Neutros */
  --color-text-primary:   #1A1A1A;
  --color-text-secondary: #5F5E5A;
  --color-border:         #E0DEDB;

  /* Semânticas */
  --color-positive:  #1D9E75;
  --color-negative:  #E24B4A;
  --color-warning:   #BA7517;
  --color-info:      #185FA5;

  /* Fills de fundo semânticos (badges, chips) */
  --color-positive-bg: #E6F5EE;
  --color-negative-bg: #FCEBEB;
  --color-warning-bg:  #FAEEDA;
  --color-info-bg:     #E6F1FB;
}
```

---

## Tailwind CSS (para uso com Tailwind)

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#A31F34',
          hover:   '#7A1626',
        },
        bg: {
          page:    '#F8F7F5',
          surface: '#FFFFFF',
        },
        ink:   '#1A1A1A',
        slate: '#5F5E5A',
        mist:  '#E0DEDB',
        positive: {
          DEFAULT: '#1D9E75',
          bg:      '#E6F5EE',
        },
        negative: {
          DEFAULT: '#E24B4A',
          bg:      '#FCEBEB',
        },
        warning: {
          DEFAULT: '#BA7517',
          bg:      '#FAEEDA',
        },
        info: {
          DEFAULT: '#185FA5',
          bg:      '#E6F1FB',
        },
      },
    },
  },
}
```

---

## Regras de uso

### MIT Red (`#A31F34`) — cor brand
- Usar em: botões primários (CTA), logo, item ativo na navegação, ícones de identidade
- **Não usar** para indicar erros ou perdas — isso é função do Loss Red

### Loss Red (`#E24B4A`) — cor semântica de negativo
- Diferente do MIT Red propositalmente: é mais vivo e saturado, lido instantaneamente como "negativo"
- Usar em: valores negativos, saídas, erros de validação

### Ice White (`#F8F7F5`) — background de página
- Tem leve temperatura quente que harmoniza com o vermelho
- O Pure White (`#FFFFFF`) fica reservado para cards — cria hierarquia visual: página → card → conteúdo

### Profit Green (`#1D9E75`) — cor semântica de positivo
- Tom sóbrio e profissional — evita verdes saturados que remetem a gaming
- Usar em: entradas, saldos positivos, metas atingidas

---

## Hierarquia de superfícies

```
Página (Ice White #F8F7F5)
  └── Card (Pure White #FFFFFF)
        └── Conteúdo / Texto (Ink #1A1A1A)
              └── Label / Caption (Slate #5F5E5A)
```

---

## Exemplos de componentes

### Botão primário
```css
background: #A31F34;
color: #FFFFFF;
/* hover: */ background: #7A1626;
```

### Botão ghost
```css
background: transparent;
color: #A31F34;
border: 1.5px solid #A31F34;
```

### Badge de valor positivo
```css
background: #E6F5EE;
color: #0F6E56; /* verde escuro da mesma família */
```

### Badge de valor negativo
```css
background: #FCEBEB;
color: #A32D2D; /* vermelho escuro da mesma família */
```

### Badge neutro / pendente
```css
background: #F1EFE8;
color: #5F5E5A;
```
