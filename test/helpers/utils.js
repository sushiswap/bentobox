sansBorrowFee = (amount) => {
  return amount.mul(2000).div(2001)
}

module.exports = {
  sansBorrowFee,
}
