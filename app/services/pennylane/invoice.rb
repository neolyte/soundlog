module Pennylane
  Invoice = Data.define(
    :id,
    :number,
    :public_file_url,
    :amount,
    :currency,
    :date
  )
end
