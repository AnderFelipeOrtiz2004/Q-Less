import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../services/auth.js';

@Component({
  selector: 'app-orders',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './orders.html',
  styleUrl: './orders.css'
})
export class OrdersComponent implements OnInit {

  userName: string | null = '';

  pedidos: any[] = [];

  constructor(
    private authService: AuthService,
    private router: Router,
    private http: HttpClient
  ) { }

  ngOnInit(): void {

    this.userName =
      localStorage.getItem('user_name') || 'Administrador';

    if (!this.authService.isAdmin()) {
      this.router.navigate(['/home']);
      return;
    }

    setTimeout(() => {

      this.obtenerPedidos();

    }, 100);
  }

  obtenerPedidos(): void {

    this.http.get<any>('http://127.0.0.1:8000/api/orders')
      .subscribe({

        next: (response) => {

          this.pedidos = response.orders || [];

          this.verificarExpiraciones();
        },

        error: (error) => {

          console.error(
            'Error obteniendo pedidos',
            error
          );
        }
      });
  }

  getRemainingTime(expiresAt: string): string {

    const expiration =
      new Date(expiresAt).getTime();

    const now =
      new Date().getTime();

    const difference =
      expiration - now;

    if (difference <= 0) {
      return 'Expirado';
    }

    const minutes =
      Math.floor(difference / 1000 / 60);

    const seconds =
      Math.floor((difference / 1000) % 60);

    return `${minutes}:${seconds
      .toString()
      .padStart(2, '0')}`;
  }

  verificarExpiraciones(): void {

    setInterval(() => {

      this.pedidos.forEach((pedido) => {

        const expiration =
          new Date(pedido.expires_at).getTime();

        const now =
          new Date().getTime();

        if (
          expiration <= now &&
          pedido.status === 'pendiente'
        ) {

          this.http.patch(

            `http://127.0.0.1:8000/api/orders/${pedido.id}/status`,

            {
              status: 'expirado'
            }

          ).subscribe({

            next: () => {

              pedido.status = 'expirado';
            }
          });
        }
      });

    }, 1000);
  }

  marcarEntregado(pedido: any): void {

    this.http.patch(

      `http://127.0.0.1:8000/api/orders/${pedido.id}/status`,

      {
        status: 'entregado'
      }

    ).subscribe({

      next: () => {

        pedido.status = 'entregado';
      },

      error: (error) => {

        console.error(
          'Error actualizando pedido',
          error
        );
      }
    });
  }

  marcarNoEntregado(pedido: any): void {

    this.http.patch(

      `http://127.0.0.1:8000/api/orders/${pedido.id}/status`,

      {
        status: 'no_entregado'
      }

    ).subscribe({

      next: () => {

        pedido.status = 'no_entregado';
      },

      error: (error) => {

        console.error(
          'Error actualizando pedido',
          error
        );
      }
    });
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/login']);
  }
}