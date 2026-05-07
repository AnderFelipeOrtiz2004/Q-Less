import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../services/auth.js';
import { CartItem, CartService } from '../../services/cart.service';

@Component({
  selector: 'app-cart',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './cart.html',
  styleUrl: './cart.css'
})
export class CartComponent implements OnInit, OnDestroy {
  cartItems: CartItem[] = [];
  total = 0;
  cartMessage = '';
  showPaymentModal = false;
  paymentSuccess = false;
  paymentErrors: string[] = [];
  paymentForm = {
    nombre: '',
    documento: '',
    metodo: 'tarjeta',
    referencia: '',
  };
  private countdownIntervalId: number | null = null;
  loadingItems = new Set<number>();

  constructor(
    private authService: AuthService,
    private cartService: CartService,
    private router: Router,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit(): void {
    this.cartService.syncCurrentUser();
    this.cartService.items$.subscribe(items => {
      this.cartItems = items.map(item => ({ ...item }));
      this.total = this.cartService.getTotal();
    });

    this.countdownIntervalId = window.setInterval(() => {
      this.cartItems = this.cartItems.map(item => {
        const remaining = Math.max(0, (item.remaining_seconds || 0) - 1);

        return {
          ...item,
          remaining_seconds: remaining,
        };
      });

      this.cdr.detectChanges();
    }, 1000);
  }

  ngOnDestroy(): void {
    if (this.countdownIntervalId !== null) {
      window.clearInterval(this.countdownIntervalId);
    }
  }

  removeItem(id: number): void {
    this.cartMessage = '';
    this.loadingItems.add(id);
    this.cartService.removeItem(id).subscribe({
      next: () => {
        this.total = this.cartService.getTotal();
        this.loadingItems.delete(id);
      },
      error: (error) => {
        console.error('Error quitando producto del carrito', error);
        this.loadingItems.delete(id);
      }
    });
  }

  increaseItem(item: CartItem): void {
    this.cartMessage = '';
    this.loadingItems.add(item.id);
    this.cartService.addItem(item).subscribe({
      next: () => {
        this.total = this.cartService.getTotal();
        this.loadingItems.delete(item.id);
      },
      error: (error) => {
        console.error('Error aumentando cantidad', error);
        this.cartMessage = error?.error?.errors?.producto_id?.[0]
          || error?.error?.errors?.carrito?.[0]
          || error?.error?.message
          || 'No se pudo aumentar la cantidad del producto.';
        this.loadingItems.delete(item.id);
      }
    });
  }

  decreaseItem(id: number): void {
    this.cartMessage = '';
    this.loadingItems.add(id);
    this.cartService.decreaseItem(id).subscribe({
      next: () => {
        this.total = this.cartService.getTotal();
        this.loadingItems.delete(id);
      },
      error: (error) => {
        console.error('Error disminuyendo cantidad', error);
        this.loadingItems.delete(id);
      }
    });
  }

  canIncrease(item: CartItem): boolean {
    return !this.loadingItems.has(item.id) && (item.stock_available || 0) > 0;
  }

  clearCart(): void {
    this.cartMessage = '';
    this.cartService.clear().subscribe({
      next: () => {
        this.total = this.cartService.getTotal();
      },
      error: (error) => {
        console.error('Error vaciando carrito', error);
      }
    });
  }

  checkout(): void {
    this.paymentErrors = [];
    this.paymentSuccess = false;
    this.paymentForm = {
      nombre: localStorage.getItem('user_name') || '',
      documento: '',
      metodo: 'tarjeta',
      referencia: '',
    };
    this.showPaymentModal = true;
  }

  get isAdmin(): boolean {
    return this.authService.isAdmin();
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }

  getImageUrl(item: CartItem): string {
    if (!item.image_path) {
      return 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="220" height="180"><rect fill="%23ececec" width="220" height="180"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-size="13">Sin imagen</text></svg>';
    }

    return item.image_path;
  }

  onImageError(event: any): void {
    event.target.src = 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="220" height="180"><rect fill="%23ececec" width="220" height="180"/><text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="Arial" font-size="13">No disponible</text></svg>';
  }

  closePaymentModal(): void {
    this.showPaymentModal = false;
    this.paymentErrors = [];
    this.paymentSuccess = false;
  }

  confirmPayment(): void {
    this.paymentErrors = [];

    if (!this.paymentForm.nombre.trim()) {
      this.paymentErrors.push('El nombre del comprador es obligatorio.');
    }

    if (!this.paymentForm.documento.trim()) {
      this.paymentErrors.push('El documento es obligatorio.');
    }

    if (!this.paymentForm.metodo.trim()) {
      this.paymentErrors.push('Debes seleccionar un metodo de pago.');
    }

    if (!this.paymentForm.referencia.trim()) {
      this.paymentErrors.push('Ingresa una referencia de pago.');
    }

    if (this.paymentErrors.length > 0) {
      return;
    }

    this.cartService.checkout(this.paymentForm).subscribe({
      next: () => {
        this.paymentSuccess = true;
        this.total = 0;
      },
      error: (error) => {
        console.error('Error confirmando pago', error);
        this.paymentErrors = [
          error?.error?.message || error?.message || 'No se pudo confirmar el pago en este momento.'
        ];
      }
    });
  }

  getRemainingTime(item: CartItem): string {
    const remaining = Math.max(0, item.remaining_seconds || 0);
    const minutes = Math.floor(remaining / 60);
    const seconds = remaining % 60;
    return `${minutes}:${String(seconds).padStart(2, '0')}`;
  }

  getTotalItems(): number {
    return this.cartItems.reduce((total, item) => total + item.cantidad, 0);
  }

  trackByProductId(_: number, item: CartItem): number {
    return item.id;
  }

  isItemLoading(id: number): boolean {
    return this.loadingItems.has(id);
  }
}
