package com.jared.territorytool.core.navigation

import android.app.Application
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.HasDefaultViewModelProviderFactory
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import java.util.UUID

/** Destino de navegación. Puede llevar modelos completos, como `NavigationLink` en iOS. */
interface Route

class NavEntry(val route: Route?) : ViewModelStoreOwner {
    val id: String = UUID.randomUUID().toString()
    override val viewModelStore = ViewModelStore()
}

/**
 * Pila de navegación de una pestaña (equivale a `NavigationStack(path:)`). Cada entrada
 * tiene su propio `ViewModelStore`, que se limpia al salir de la pila.
 */
class Navigator {
    val root = NavEntry(null)
    val stack = mutableStateListOf<NavEntry>()

    val isAtRoot: Boolean get() = stack.isEmpty()

    fun push(route: Route) {
        stack.add(NavEntry(route))
    }

    fun pop() {
        stack.removeLastOrNull()?.viewModelStore?.clear()
    }

    fun popToRoot() {
        stack.forEach { it.viewModelStore.clear() }
        stack.clear()
    }
}

val LocalNavigator = staticCompositionLocalOf<Navigator> { error("No Navigator") }

@Composable
fun NavStackHost(
    navigator: Navigator,
    enableBack: Boolean = true,
    root: @Composable () -> Unit,
    destination: @Composable (Route) -> Unit,
) {
    val holder = rememberSaveableStateHolder()
    val app = LocalContext.current.applicationContext as Application
    val current = navigator.stack.lastOrNull() ?: navigator.root
    BackHandler(enabled = enableBack && !navigator.isAtRoot) { navigator.pop() }

    CompositionLocalProvider(LocalNavigator provides navigator) {
        AnimatedContent(
            targetState = current,
            transitionSpec = {
                val forward = navigator.stack.indexOf(targetState) > navigator.stack.indexOf(initialState)
                if (forward) {
                    (slideInHorizontally(tween(320)) { it } + fadeIn(tween(200))) togetherWith
                        (slideOutHorizontally(tween(320)) { -it / 4 } + fadeOut(tween(200)))
                } else {
                    (slideInHorizontally(tween(320)) { -it / 4 } + fadeIn(tween(200))) togetherWith
                        (slideOutHorizontally(tween(320)) { it } + fadeOut(tween(200)))
                }
            },
            label = "nav",
        ) { entry ->
            holder.SaveableStateProvider(entry.id) {
                // Fábrica por defecto para que `viewModel()` también cree `AndroidViewModel`s.
                val owner = remember(entry) {
                    object : ViewModelStoreOwner, HasDefaultViewModelProviderFactory {
                        override val viewModelStore = entry.viewModelStore
                        override val defaultViewModelProviderFactory = ViewModelProvider.AndroidViewModelFactory.getInstance(app)
                    }
                }
                CompositionLocalProvider(LocalViewModelStoreOwner provides owner) {
                    val route = entry.route
                    if (route == null) root() else destination(route)
                }
            }
            DisposableEffect(entry) {
                onDispose {
                    if (entry !== navigator.root && entry !in navigator.stack) holder.removeState(entry.id)
                }
            }
        }
    }
}

@Composable
fun rememberNavigator(): Navigator = remember { Navigator() }
