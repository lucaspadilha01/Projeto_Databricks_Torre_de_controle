// O warehouse devolve todo número como string: sempre Number() antes de formatar.
const brl = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
const brlMi = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const indice = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const umaCasa = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const inteiro = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 0 });

export const formatarReais = (valor: number | string): string => brl.format(Number(valor));

/** R$ em milhões (ou mil, abaixo de 1 mi): "R$ 6,47 mi", "R$ 30,1 mil". */
export const formatarReaisCurto = (valor: number | string): string => {
  const n = Number(valor);
  if (Math.abs(n) >= 1_000_000) return `R$ ${brlMi.format(n / 1_000_000)} mi`;
  if (Math.abs(n) >= 1_000) return `R$ ${umaCasa.format(n / 1_000)} mil`;
  return brl.format(n);
};

export const formatarIndice = (valor: number | string): string => indice.format(Number(valor));
export const formatarDecimal = (valor: number | string): string => umaCasa.format(Number(valor));
export const formatarInteiro = (valor: number | string): string => inteiro.format(Number(valor));
export const formatarPercentual = (valor: number | string): string => `${inteiro.format(Number(valor) * 100)}%`;
