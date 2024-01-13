const getPrice = (sqrtPriceX96: bigint): number => {
  const Decimal0: number = 18;
  const Decimal1: number = 18;

  const buyOneOfToken0 =
    (Number(sqrtPriceX96) / 2 ** 96) ** 2 /
    Number((10 ** Decimal1 / 10 ** Decimal0).toFixed(Decimal1));

  // const buyOneOfToken1: number = Number((1 / buyOneOfToken0).toFixed(Decimal0));
  return buyOneOfToken0;
};

export default getPrice;
