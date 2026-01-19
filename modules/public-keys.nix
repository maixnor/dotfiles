let
  # YOUR USER KEYS (For SSH Login)
  users = {
    maixnor = [
      # bierzelt-rsa
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCwGqcBJ6aOYBilComuDTG6iW1z5FJ9I8rGgWhP3sUxHrpd47evuEuDDDfen7TkldtbvIQrbhWJ90Um6kCaKsEFh6kMUvraHLaqcd0dMSs9/xovRhPWmpVsGnnwjtDbxCvjEdoUgt28eRhn/CBjaprg4JYNWtrVbIdcjIL7Aho915G913QGK85qWzhx6eqomZpvNB90CbFHH6gtbRiQzwLO65SuOeJHa4iJ205JM7ivJduOgvyV1agYcxuh8MDWQpCsLUfrKsUYnm8o+NqcCHUc7/kCxgHXdC1QEc4m0ralTI9GoUuaY7z428YjjsM61cQuM3vmiDGakitJ7zWXBQ7avYHAFPbWHRXFqR6SGB3yxMExXTtYVvPBXaSbAMYPZeX0UMyLBZZLMCQf7eUm3zKH4z7wmMoPdiKGMkx0obhxQqtDCgYLj9ixqMwJvuzHhfB38vAkbP64ikhTx5uCTf1WuC4/C8wuVX14sESQxAMJvDwe+A83EFzZyaMx5MsCWlnvs42ygYKGBQ/Bfy6YrGviR+ePtiBHyUB1elaTH9kIMm17/MUOiu7HpA+88XuNaIQ9DpXpFv8uE/X/7aju1f5F8Qxj1tly7EEtiv2QfS5j1g0AmftgEPQu93WCABE6+DSoGmwZuxIquhhuskWXLWasJPXcBM5fMvVgBclSKbOb9w== maixnor@bierzelt"
      # bierzelt-ed
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDgUQR0j3mbUxeCpPJkW2wFjvXqT6WJ53NsZ1q5tRq5C maixnor@bierzelt"

      # bierbasis-rsa
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDA2UypJYZ7g0TWU1F3PlOkZNwdrFRHPs1pUGmG7kqTTxT0I5NZroQZn1NKKqqFc8H/75bVtja2n0SvpO5PLN2lwaCp60rG1Jz5RCiZ/Fg10VRmawKnx8yOePlOmmchE0ldT5RX84oYKtZbJuLjETMdy/poizyGrBVDQjx8/neI9QEgrbgIZ0WyWu6Cv5Jh2oqZRycVI3ip3oYcEjostLDHmVDW1uaV8qAzIBeL1cGYomW9PxD+pKIelZsPpaBGZrJkjr+1h1FXV1Uh/HQenbMO/qP9ydQzhwpGZ+t6DIy2gwrY2C7WdaJIdWCe6gMk5gPITsYPgS+1Vi58nUGlxOR+VucwYPICIVGYTVFdOr0f9jWrFxtUNuOSyEHExzxlLZJ0EQgRykzNI5rJwMvCBewpnAnaVyHaPM74UKKSXrvjBaYBvJwcwDJDYxn3jkB0YCj0RPsZEBXZzimj7Mh+0oJJ+NGtJ32VtdNDY0bYJoI16sAqIojkYYqEvrOykWwTkfs= maixnor@Bierbasis"
      # bierbasis-ed
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDSEUhvHm1W2rcOjvTU9oEhbXoIR9SlCcF4MaOLDAlhv maixnor@Bierbasis"

      # wieselburg-rsa
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDccFBNnr7PFPslH32SxVAv4WiSmZLadUz06/LBSX6M11dB/ui7yRxAXk5zrZPqLnI1vmH1a3ZqCg71FVCDaPuscEoMsOTCU/ot2Cj88LAkU1s6iS4eYEN4qNsv1qHm+6fYkM7Poxlx6dQKsGTwVLqQIvBY/Gl2VyYOSVTCkTQfndYNUp0YNi13/tahYVhZQJAOWCoNkTupgtq9jXpnb9sUpI3c5LaTJ9vFzGK1NV6/W2jAeGaxSRIU6QS67Tw2tTFRqHpAddbxnnISC3iXsT0V9m7Fqz3eAlHuyLX4V2IZUtoj28QOpIp45hjSe4HzHTmpr9rm3uMaA1tuWWVVj2YTN/uOD9QMoUHgRU1yw8LIfL4VVjn3IDUpeKEF67ulztvJDRu7OohulmQxwPrtNs+WAwQCk5F8pvUj7nEXgRKFEc3vUrVwcOXbnZH4GeQYW2Ekk49hoUb6J/ySl1UrbSrvxKMTl/2WYmrkoqLyoO8hIPJEFvoGALizXLkMj4jhxCWDNlhEWfSFG4ZVvzhqTMzPkmM06WROmOhRaX0nRpJ1RLzx82HjJNeD0Bv2+VdkryP6wxbmFzjT8IapzD8MlF9w0oRFARRPobZcQAnJYOGAW4Xv71+EZytH84IibzF0szhp/ecsUPiCQxOlsXqwBX9aEn5bKD+cqlXPky0L6jstjw== maixnor@wieselburg"
      # wieselburg-ed
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDxCQgXMMthOLAM2ewMIB2Xudns+bFjnFrGAyUOFjPa maixnor@wieselburg"
    ];
  };

  # HOST KEYS (For Agenix Decryption)
  hosts = {
    wieselburg = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9onF8hjTqY9iuWwv1eCjIhkwnBlmU8n9+foef422/H root@nixos";
    bierzelt   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILCK7tXv+thAIgB3BMFgBPq56LuzVmVkSg6/mpDmpEfT root@bierzelt";
    bierbasis  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHJWpPGBkuLR6riBJT3xIFKRjYfIWdJ4PieuF1qbTjnn root@Bierbasis";
  };
in
{
  inherit users hosts;
}
