# JHAVÈ Official — negozio online

Vetrina e-commerce statica, ottimizzata per smartphone, per il brand JHAVÈ.

## Pubblicazione gratuita
1. Aprire **Settings → Pages** nel repository.
2. In **Build and deployment**, scegliere **Deploy from a branch**.
3. Selezionare branch **main** e cartella **/(root)**, poi Save.
4. Il sito sarà disponibile all'indirizzo GitHub Pages mostrato nella stessa schermata.

## Foto prodotti
Caricare le fotografie nella cartella `assets/` con questi nomi:
- `jeans.jpg`
- `pantaloni-sartoriali.jpg`
- `tshirt-filo-scozia.jpg`

È possibile caricare più foto insieme da iPhone usando GitHub → Add file → Upload files.

## Dati da configurare prima di vendere
Aprire `index.html` e cercare `const STORE`:
- `whatsapp`: numero internazionale senza + (es. 393331234567).
- `paypalMe`: link PayPal.Me del conto del venditore.

Cercare poi `const PRODUCTS` e inserire il prezzo numerico in euro per ciascun articolo al posto di `null`.

**Importante:** non inserire mai password, chiavi API o segreti PayPal nel repository. Il link PayPal.Me è pubblico, non una credenziale. PayPal.Me è una soluzione iniziale semplice; per un checkout e-commerce completo con gestione automatica degli ordini, spedizioni e conferme servirà integrare PayPal Checkout tramite un backend sicuro.

## Stato attuale
- Catalogo iniziale con tre schede modificabili.
- Filtri per pantaloni e T-shirt.
- Selezione taglia e carrello.
- Pulsanti PayPal e WhatsApp predisposti ma non attivi finché non vengono configurati prezzi e contatti.
- Le fotografie originali non sono ancora state caricate.
